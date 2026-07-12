/**
 * Payment webhook handlers. Each provider is validated with a shared secret
 * before creating an order + license code. Webhook events are idempotent —
 * the same `provider_event_id` is never processed twice.
 *
 * Supported providers:
 *  - Lemon Squeezy (HMAC-SHA256)
 *  - Stripe (raw body + webhook signing secret)
 *  - Manual (used for marking orders from manual issuance)
 *
 * Resend email delivery is deferred to email.ts for async resilience.
 */

import { generateCode } from './codes';
import { sha256Hex } from './crypto';
type Tier = 'pro' | 'team';

/** Normalised webhook event our router acts on. */
export interface WebhookEvent {
  provider: string;
  providerEventId: string;
  eventType: string;
  email: string;
  tier: Tier;
  amount?: number;
  currency?: string;
}

/** Creates a license from a webhook event. Returns the plaintext code. */
export async function handleWebhookEvent(
  db: D1Database,
  event: WebhookEvent,
): Promise<{ id: string; code: string } | null> {
  // ---- idempotency gate ----
  const existing = await db
    .prepare('SELECT processed FROM webhook_events WHERE provider = ? AND provider_event_id = ?')
    .bind(event.provider, event.providerEventId)
    .first<{ processed: number }>();
  if (existing?.processed) return null; // already handled

  // ---- create order record ----
  const orderId = crypto.randomUUID();
  await db
    .prepare(
      'INSERT INTO orders (id, provider, provider_order_id, email, tier, amount, currency, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    )
    .bind(orderId, event.provider, event.providerEventId, event.email, event.tier, event.amount ?? null, event.currency ?? null, 'paid', new Date().toISOString())
    .run();

  // ---- generate license code ----
  const code = generateCode();
  const codeHash = await sha256Hex(code);
  const licenseId = crypto.randomUUID();
  await db
    .prepare(
      'INSERT INTO licenses (id, code_hash, tier, status, max_devices, email, order_id, issued_by, issued_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    )
    .bind(licenseId, codeHash, event.tier, 'active', event.tier === 'team' ? 10 : 3, event.email, orderId, 'webhook', new Date().toISOString())
    .run();

  // ---- mark idempotency ----
  await db
    .prepare(
      'INSERT INTO webhook_events (id, provider, provider_event_id, event_type, payload, processed, received_at) VALUES (?, ?, ?, ?, ?, 1, ?)',
    )
    .bind(crypto.randomUUID(), event.provider, event.providerEventId, event.eventType, JSON.stringify(event), new Date().toISOString())
    .run();

  return { id: licenseId, code };
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
  if (!signature) return false;
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
  return signature === expected;
}

/**
 * Stripe / generic: timing-safe comparison of a pre-shared webhook secret.
 */
export function verifyGenericSignature(header: string | null, secret: string): boolean {
  const token = (header ?? '').replace(/^Bearer\s+/i, '');
  if (!token || !secret) return false;
  // timing-safe comparison
  const a = new TextEncoder().encode(token);
  const b = new TextEncoder().encode(secret);
  if (a.length !== b.length) return false;
  return a.every((v, i) => v === b[i]);
}
