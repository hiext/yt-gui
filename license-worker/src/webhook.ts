/**
 * 支付 webhook 处理器。接受载荷前必须先用共享密钥完成验签。
 *
 * 当前支持：
 *   - Lemon Squeezy：X-Signature 请求头中的 HMAC-SHA256
 *
 * D1 原子写入完成后，由路由层调用 Resend 投递邮件。
 */

import { sha256Hex } from './crypto.ts';
type Tier = 'pro' | 'team';

/** 路由层处理的标准化 webhook 事件。 */
export interface WebhookEvent {
  provider: string;
  providerEventId: string;
  providerOrderId: string;
  eventType: string;
  email: string;
  tier: Tier;
  amount?: number;
  currency?: string;
}

export interface WebhookIssueResult {
  id: string;
  orderId: string;
  code?: string;
  orderStatus: string;
  created: boolean;
}

export type LemonSqueezyParseResult =
  | { kind: 'paid'; event: WebhookEvent }
  | { kind: 'ignored'; eventType: string }
  | { kind: 'error'; status: 400 | 422 | 503; error: string };

function parseVariantIds(value: string | undefined): Set<string> {
  return new Set((value ?? '').split(',').map((item) => item.trim()).filter(Boolean));
}

function nonEmptyString(value: unknown): string {
  if (typeof value === 'string') return value.trim();
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return '';
}

/** 仅把 Lemon Squeezy 的已付款订单事件规范化为可签发事件。 */
export function parseLemonSqueezyPaidOrder(
  rawBody: string,
  proVariantIdsValue: string | undefined,
  teamVariantIdsValue: string | undefined,
): LemonSqueezyParseResult {
  let body: Record<string, any>;
  try {
    body = JSON.parse(rawBody) as Record<string, any>;
  } catch {
    return { kind: 'error', status: 400, error: 'invalid json' };
  }

  const eventType = nonEmptyString(body.meta?.event_name);
  if (!eventType) return { kind: 'error', status: 400, error: 'missing event type' };
  if (eventType !== 'order_created') return { kind: 'ignored', eventType };

  const attributes = body.data?.attributes;
  if (!attributes || typeof attributes !== 'object') {
    return { kind: 'error', status: 400, error: 'missing order attributes' };
  }
  if (nonEmptyString(attributes.status).toLowerCase() !== 'paid') {
    return { kind: 'error', status: 422, error: 'order is not paid' };
  }

  const proVariantIds = parseVariantIds(proVariantIdsValue);
  const teamVariantIds = parseVariantIds(teamVariantIdsValue);
  if (proVariantIds.size === 0 && teamVariantIds.size === 0) {
    return { kind: 'error', status: 503, error: 'variant mapping not configured' };
  }
  for (const id of proVariantIds) {
    if (teamVariantIds.has(id)) {
      return { kind: 'error', status: 503, error: 'variant mapping is ambiguous' };
    }
  }

  const variantId = nonEmptyString(attributes.first_order_item?.variant_id);
  if (teamVariantIds.has(variantId)) {
    return { kind: 'error', status: 503, error: 'team billing lifecycle not supported' };
  }
  const tier: Tier | null = proVariantIds.has(variantId) ? 'pro' : null;
  if (!tier) return { kind: 'error', status: 422, error: 'unmapped variant' };

  const providerOrderId = nonEmptyString(body.data?.id);
  if (!providerOrderId) return { kind: 'error', status: 400, error: 'missing order id' };
  const email = nonEmptyString(attributes.user_email).toLowerCase();
  if (!email || email.length > 320 || !email.includes('@')) {
    return { kind: 'error', status: 400, error: 'invalid email' };
  }

  const total = Number(attributes.total);
  const currency = nonEmptyString(attributes.currency).toUpperCase();
  return {
    kind: 'paid',
    event: {
      provider: 'lemonsqueezy',
      providerEventId: `${eventType}:${providerOrderId}`,
      providerOrderId,
      eventType,
      email,
      tier,
      amount: Number.isFinite(total) ? total : undefined,
      currency: currency || undefined,
    },
  };
}

/** 原子创建订单和授权；重复事件只在邮件未完成时返回同一派生码。 */
export async function handleWebhookEvent(
  db: D1Database,
  event: WebhookEvent,
  code: string,
): Promise<WebhookIssueResult> {
  const existing = await db
    .prepare('SELECT processed FROM webhook_events WHERE provider = ? AND provider_event_id = ?')
    .bind(event.provider, event.providerEventId)
    .first<{ processed: number }>();
  if (existing?.processed) {
    const order = await db
      .prepare(
        'SELECT o.id, o.license_id, o.status, l.code_hash FROM orders o JOIN licenses l ON l.id = o.license_id WHERE o.provider = ? AND o.provider_order_id = ?',
      )
      .bind(event.provider, event.providerOrderId)
      .first<{ id: string; license_id: string; status: string; code_hash: string }>();
    if (!order) throw new Error('processed webhook order is missing');
    if (order.status === 'fulfilled') {
      return {
        id: order.license_id,
        orderId: order.id,
        orderStatus: order.status,
        created: false,
      };
    }
    const derivedHash = await sha256Hex(code);
    if (order.code_hash !== derivedHash) {
      throw new Error('license code secret does not match existing order');
    }
    return {
      id: order.license_id,
      orderId: order.id,
      code,
      orderStatus: order.status,
      created: false,
    };
  }

  const orderId = crypto.randomUUID();
  const codeHash = await sha256Hex(code);
  const licenseId = crypto.randomUUID();
  const createdAt = new Date().toISOString();
  try {
    await db.batch([
      db
        .prepare(
          'INSERT INTO orders (id, provider, provider_order_id, email, tier, amount, currency, status, license_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        )
        .bind(orderId, event.provider, event.providerOrderId, event.email, event.tier, event.amount ?? null, event.currency ?? null, 'email_pending', licenseId, createdAt),
      db
        .prepare(
          'INSERT INTO licenses (id, code_hash, tier, status, max_devices, email, order_id, issued_by, issued_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        )
        .bind(licenseId, codeHash, event.tier, 'active', event.tier === 'team' ? 10 : 3, event.email, orderId, 'webhook', createdAt),
      db
        .prepare(
          'INSERT INTO webhook_events (id, provider, provider_event_id, event_type, payload, processed, received_at) VALUES (?, ?, ?, ?, ?, 1, ?)',
        )
        .bind(crypto.randomUUID(), event.provider, event.providerEventId, event.eventType, JSON.stringify(event), createdAt),
    ]);
  } catch (error) {
    const duplicate = await db
      .prepare('SELECT processed FROM webhook_events WHERE provider = ? AND provider_event_id = ?')
      .bind(event.provider, event.providerEventId)
      .first<{ processed: number }>();
    if (duplicate?.processed) return handleWebhookEvent(db, event, code);
    throw error;
  }

  return { id: licenseId, orderId, code, orderStatus: 'email_pending', created: true };
}

// ── Provider-specific verification ──

/**
 * Lemon Squeezy: verify HMAC-SHA256 signature.
 * https://docs.lemonsqueezy.com/api/webhooks#signing-requests
 */
export async function verifyLemonSqueezySignature(
  rawBody: string,
  signature: string | null,
  secret: string,
): Promise<boolean> {
  if (!signature || !secret.trim()) return false;
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody));
  const expected = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return timingSafeEqual(signature.toLowerCase(), expected);
}

function timingSafeEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}
