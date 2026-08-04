/**
 * Hiext License Worker — activation / validation / device binding + admin issuance.
 * Online activation with device binding; entitlement tokens are Ed25519-signed
 * so the desktop app can verify offline during a grace window.
 */

import { sha256Hex, signEntitlementToken, type EntitlementClaims } from './crypto.ts';
import { deriveCode, generateCode, isValidCodeFormat, normalizeCode } from './codes.ts';
import { checkRateLimit, type RateLimitBinding } from './rate_limit.ts';
import { verifyTurnstile } from './turnstile.ts';
import { sendLicenseEmail } from './email.ts';
import {
  handleWebhookEvent,
  parseLemonSqueezyPaidOrder,
  verifyLemonSqueezySignature,
} from './webhook.ts';

interface Env {
  DB: D1Database;
  RATE_LIMIT_KV: RateLimitBinding;
  ADMIN_TOKEN: string;
  ED25519_PRIVATE_KEY: string;
  ED25519_PUBLIC_KEY: string;
  TURNSTILE_SECRET_KEY?: string;
  WEBHOOK_SECRET?: string;
  LICENSE_CODE_SECRET?: string;
  RESEND_API_KEY?: string;
  LICENSE_FROM_EMAIL?: string;
  LEMONSQUEEZY_PRO_VARIANT_IDS?: string;
  LEMONSQUEEZY_TEAM_VARIANT_IDS?: string;
}

type Tier = 'pro' | 'team';

interface LicenseRow {
  id: string;
  code_hash: string;
  tier: Tier;
  status: string;
  max_devices: number;
  email: string | null;
  order_id: string | null;
  issued_by: string;
  issued_at: string;
  expires_at: string | null;
  meta: string | null;
}

interface DeviceRow {
  id: string;
  fingerprint: string;
  device_name: string | null;
  platform: string | null;
  activated_at: string;
  last_seen_at: string | null;
}

// Token lifetime: how long an offline app may trust a cached entitlement.
const TOKEN_TTL_SECONDS: Record<Tier, number> = {
  pro: 14 * 24 * 60 * 60,
  team: 7 * 24 * 60 * 60,
};

const DEFAULT_MAX_DEVICES: Record<Tier, number> = { pro: 3, team: 10 };

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'cache-control': 'no-store',
      'content-type': 'application/json; charset=UTF-8',
    },
  });
}

function nowIso(): string {
  return new Date().toISOString();
}

function uuid(): string {
  return crypto.randomUUID();
}

async function readJson(request: Request): Promise<Record<string, unknown>> {
  try {
    const parsed = await request.json();
    return typeof parsed === 'object' && parsed !== null ? (parsed as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

function clientIp(request: Request): string {
  return request.headers.get('cf-connecting-ip') ?? 'unknown';
}

function isExpired(license: LicenseRow): boolean {
  return license.expires_at !== null && new Date(license.expires_at).getTime() < Date.now();
}

async function issueToken(env: Env, license: LicenseRow, fingerprint: string): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const claims: EntitlementClaims = {
    tier: license.tier,
    fingerprint,
    licenseId: license.id,
    iat,
    exp: iat + TOKEN_TTL_SECONDS[license.tier],
  };
  return signEntitlementToken(claims, env.ED25519_PRIVATE_KEY);
}

async function findLicenseByCode(env: Env, code: string): Promise<LicenseRow | null> {
  const codeHash = await sha256Hex(normalizeCode(code));
  return env.DB.prepare('SELECT * FROM licenses WHERE code_hash = ?').bind(codeHash).first<LicenseRow>();
}

// ── Public endpoints ──

async function handleActivate(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const code = String(body.code ?? '');
  const fingerprint = String(body.fingerprint ?? '');
  const deviceName = body.deviceName ? String(body.deviceName) : null;
  const platform = body.platform ? String(body.platform) : null;

  if (!isValidCodeFormat(code)) {
    return json(400, { success: false, error: 'invalid code format' });
  }
  if (!fingerprint) {
    return json(400, { success: false, error: 'missing fingerprint' });
  }

  const license = await findLicenseByCode(env, code);
  if (!license || license.status !== 'active' || isExpired(license)) {
    return json(403, { success: false, error: 'license not active' });
  }

  const existing = await env.DB.prepare(
    'SELECT * FROM devices WHERE license_id = ? AND fingerprint = ? AND deactivated_at IS NULL',
  )
    .bind(license.id, fingerprint)
    .first();

  if (!existing) {
    const activeCount = await env.DB.prepare(
      'SELECT COUNT(*) AS n FROM devices WHERE license_id = ? AND deactivated_at IS NULL',
    )
      .bind(license.id)
      .first<{ n: number }>();
    if ((activeCount?.n ?? 0) >= license.max_devices) {
      return json(409, {
        success: false,
        error: 'device limit reached',
        maxDevices: license.max_devices,
        activeDevices: activeCount?.n ?? 0,
      });
    }
    await env.DB.prepare(
      'INSERT INTO devices (id, license_id, fingerprint, device_name, platform, activated_at, last_seen_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
    )
      .bind(uuid(), license.id, fingerprint, deviceName, platform, nowIso(), nowIso())
      .run();
  } else {
    await env.DB.prepare('UPDATE devices SET last_seen_at = ? WHERE license_id = ? AND fingerprint = ?')
      .bind(nowIso(), license.id, fingerprint)
      .run();
  }

  const token = await issueToken(env, license, fingerprint);
  return json(200, {
    success: true,
    tier: license.tier,
    token,
    expiresAt: license.expires_at,
    maxDevices: license.max_devices,
  });
}

async function handleValidate(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const code = String(body.code ?? '');
  const fingerprint = String(body.fingerprint ?? '');
  if (!fingerprint) {
    return json(400, { success: false, error: 'missing fingerprint' });
  }

  const license = await findLicenseByCode(env, code);
  if (!license || license.status !== 'active' || isExpired(license)) {
    return json(403, { success: false, error: 'license not active' });
  }

  const device = await env.DB.prepare(
    'SELECT id FROM devices WHERE license_id = ? AND fingerprint = ? AND deactivated_at IS NULL',
  )
    .bind(license.id, fingerprint)
    .first();
  if (!device) {
    return json(403, { success: false, error: 'device not bound' });
  }

  await env.DB.prepare('UPDATE devices SET last_seen_at = ? WHERE license_id = ? AND fingerprint = ?')
    .bind(nowIso(), license.id, fingerprint)
    .run();

  const token = await issueToken(env, license, fingerprint);
  return json(200, { success: true, tier: license.tier, token, expiresAt: license.expires_at });
}

async function handleDeactivate(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const code = String(body.code ?? '');
  const fingerprint = String(body.fingerprint ?? '');
  const license = await findLicenseByCode(env, code);
  if (!license) {
    return json(403, { success: false, error: 'license not found' });
  }
  await env.DB.prepare(
    'UPDATE devices SET deactivated_at = ? WHERE license_id = ? AND fingerprint = ? AND deactivated_at IS NULL',
  )
    .bind(nowIso(), license.id, fingerprint)
    .run();
  return json(200, { success: true });
}

async function findManageableLicense(env: Env, code: string): Promise<LicenseRow | Response> {
  if (!isValidCodeFormat(code)) {
    return json(400, { success: false, error: 'invalid code format' });
  }
  const license = await findLicenseByCode(env, code);
  if (!license || license.status !== 'active' || isExpired(license)) {
    return json(403, { success: false, error: 'license not active' });
  }
  return license;
}

async function handleListDevices(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const code = String(body.code ?? '');
  const currentFingerprint = String(body.currentFingerprint ?? '');
  const license = await findManageableLicense(env, code);
  if (license instanceof Response) return license;

  const result = await env.DB.prepare(
    'SELECT id, fingerprint, device_name, platform, activated_at, last_seen_at FROM devices WHERE license_id = ? AND deactivated_at IS NULL ORDER BY activated_at ASC',
  )
    .bind(license.id)
    .all<DeviceRow>();
  const devices = result.results.map((device) => ({
    id: device.id,
    deviceName: device.device_name,
    platform: device.platform,
    activatedAt: device.activated_at,
    lastSeenAt: device.last_seen_at,
    isCurrent: currentFingerprint.length > 0 && device.fingerprint === currentFingerprint,
  }));
  return json(200, {
    success: true,
    maxDevices: license.max_devices,
    activeDevices: devices.length,
    devices,
  });
}

async function handleDeactivateDevice(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);
  const code = String(body.code ?? '');
  const deviceId = String(body.deviceId ?? '').trim();
  if (!deviceId) {
    return json(400, { success: false, error: 'missing device id' });
  }
  const license = await findManageableLicense(env, code);
  if (license instanceof Response) return license;

  const device = await env.DB.prepare(
    'SELECT id FROM devices WHERE id = ? AND license_id = ?',
  )
    .bind(deviceId, license.id)
    .first<{ id: string }>();
  if (!device) {
    return json(404, { success: false, error: 'device not found' });
  }
  await env.DB.prepare(
    'UPDATE devices SET deactivated_at = COALESCE(deactivated_at, ?) WHERE id = ? AND license_id = ?',
  )
    .bind(nowIso(), deviceId, license.id)
    .run();
  return json(200, { success: true, deactivatedDeviceId: deviceId });
}

// ── Admin endpoints ──

function isAdmin(request: Request, env: Env): boolean {
  const header = request.headers.get('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  return token.length > 0 && token === env.ADMIN_TOKEN;
}

async function handleAdminCreateLicense(request: Request, env: Env): Promise<Response> {
  const body = await readJson(request);

  // Second factor: require a valid Turnstile token when a secret is configured.
  const turnstile = await verifyTurnstile(
    body.turnstileToken ? String(body.turnstileToken) : undefined,
    env.TURNSTILE_SECRET_KEY,
    clientIp(request),
  );
  if (!turnstile.ok) {
    return json(403, { success: false, error: `turnstile: ${turnstile.error}` });
  }

  const tier = body.tier === 'team' ? 'team' : 'pro';
  const count = Math.min(Math.max(Number(body.count ?? 1), 1), 100);
  const maxDevices = Number(body.maxDevices ?? DEFAULT_MAX_DEVICES[tier]);
  const email = body.email ? String(body.email) : null;
  const expiresAt = body.expiresAt ? String(body.expiresAt) : null;
  if (tier === 'team') {
    const expiresAtMillis = expiresAt == null ? Number.NaN : Date.parse(expiresAt);
    if (!Number.isFinite(expiresAtMillis) || expiresAtMillis <= Date.now()) {
      return json(400, {
        success: false,
        error: 'team expiresAt must be a future ISO-8601 timestamp',
      });
    }
  }

  const created: Array<{ id: string; code: string }> = [];
  for (let i = 0; i < count; i++) {
    const code = generateCode();
    const codeHash = await sha256Hex(code);
    const id = uuid();
    await env.DB.prepare(
      'INSERT INTO licenses (id, code_hash, tier, status, max_devices, email, issued_by, issued_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    )
      .bind(id, codeHash, tier, 'active', maxDevices, email, 'manual', nowIso(), expiresAt)
      .run();
    created.push({ id, code });
  }
  return json(200, { success: true, tier, maxDevices, licenses: created });
}

async function handleAdminGetLicense(env: Env, id: string): Promise<Response> {
  const license = await env.DB.prepare('SELECT * FROM licenses WHERE id = ?').bind(id).first<LicenseRow>();
  if (!license) {
    return json(404, { success: false, error: 'not found' });
  }
  const devices = await env.DB.prepare('SELECT * FROM devices WHERE license_id = ?').bind(id).all();
  const { code_hash: _codeHash, ...safe } = license;
  return json(200, { success: true, license: safe, devices: devices.results });
}

async function handleAdminSetStatus(env: Env, id: string, status: string): Promise<Response> {
  await env.DB.prepare('UPDATE licenses SET status = ? WHERE id = ?').bind(status, id).run();
  return json(200, { success: true, id, status });
}

// ── Webhook 分发 ──

async function handleWebhookDispatch(request: Request, env: Env, path: string): Promise<Response> {
    const provider = path.split('/webhooks/')[1]?.split('/')[0] ?? '';
    if (provider !== 'lemonsqueezy') {
      return json(404, { success: false, error: 'unsupported webhook provider' });
    }
    if (
      !env.WEBHOOK_SECRET
      || !env.LICENSE_CODE_SECRET
      || env.LICENSE_CODE_SECRET.trim().length < 32
      || !env.RESEND_API_KEY
    ) {
      return json(503, { success: false, error: 'webhook delivery not configured' });
    }

    const signature = request.headers.get('x-signature');
    const rawBody = await request.text();
    const verified = await verifyLemonSqueezySignature(rawBody, signature, env.WEBHOOK_SECRET);
    if (!verified) {
      return json(401, { success: false, error: 'invalid signature' });
    }

    const parsed = parseLemonSqueezyPaidOrder(
      rawBody,
      env.LEMONSQUEEZY_PRO_VARIANT_IDS,
      env.LEMONSQUEEZY_TEAM_VARIANT_IDS,
    );
    if (parsed.kind === 'ignored') {
      return json(200, { success: true, ignored: true, eventType: parsed.eventType });
    }
    if (parsed.kind === 'error') {
      return json(parsed.status, { success: false, error: parsed.error });
    }

    const event = parsed.event;
    const code = await deriveCode(
      env.LICENSE_CODE_SECRET,
      `${event.provider}:${event.providerEventId}`,
    );
    const result = await handleWebhookEvent(env.DB, event, code);
    if (!result.code && result.orderStatus === 'fulfilled') {
      return json(200, { success: true, alreadyProcessed: true, emailDelivered: true });
    }

    const delivery = await sendLicenseEmail(
      {
        RESEND_API_KEY: env.RESEND_API_KEY,
        LICENSE_FROM_EMAIL: env.LICENSE_FROM_EMAIL,
      },
      event.email,
      result.code ?? code,
      event.tier,
    );
    await env.DB.prepare('UPDATE orders SET status = ? WHERE id = ?')
      .bind(delivery.ok ? 'fulfilled' : 'email_failed', result.orderId)
      .run();
    if (!delivery.ok) {
      console.error('license email delivery failed', result.orderId, delivery.error);
      return json(503, { success: false, error: 'license email delivery failed' });
    }
    return json(200, {
      success: true,
      tier: event.tier,
      emailDelivered: true,
      alreadyProcessed: !result.created,
    });
}

// ── Router ──

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === 'GET' && path === '/v1/license/health') {
      return json(200, { ok: true });
    }

    // Rate-limit public write endpoints by IP + fingerprint.
    if (request.method === 'POST' && path.startsWith('/v1/license/') && !path.includes('/admin/')) {
      const ip = clientIp(request);
      const rl = await checkRateLimit(env.RATE_LIMIT_KV, `lic:${ip}`, 20, 60);
      if (!rl.allowed) {
        return json(429, { success: false, error: 'rate limited' });
      }
    }

    if (request.method === 'POST' && path === '/v1/license/activate') {
      return handleActivate(request, env);
    }
    if (request.method === 'POST' && path === '/v1/license/validate') {
      return handleValidate(request, env);
    }
    if (request.method === 'POST' && path === '/v1/license/deactivate') {
      return handleDeactivate(request, env);
    }
    if (request.method === 'POST' && path === '/v1/license/devices/list') {
      return handleListDevices(request, env);
    }
    if (request.method === 'POST' && path === '/v1/license/devices/deactivate') {
      return handleDeactivateDevice(request, env);
    }

    // Admin
    if (path.startsWith('/v1/license/admin/')) {
      if (!isAdmin(request, env)) {
        return json(401, { success: false, error: 'unauthorized' });
      }
      if (request.method === 'POST' && path === '/v1/license/admin/licenses') {
        return handleAdminCreateLicense(request, env);
      }
      const detail = path.match(/^\/v1\/license\/admin\/licenses\/([^/]+)$/);
      if (request.method === 'GET' && detail) {
        return handleAdminGetLicense(env, detail[1]);
      }
      const revoke = path.match(/^\/v1\/license\/admin\/licenses\/([^/]+)\/revoke$/);
      if (request.method === 'POST' && revoke) {
        return handleAdminSetStatus(env, revoke[1], 'revoked');
      }
      const refund = path.match(/^\/v1\/license\/admin\/licenses\/([^/]+)\/refund$/);
      if (request.method === 'POST' && refund) {
        return handleAdminSetStatus(env, refund[1], 'refunded');
      }
    }

    // 支付 webhook：目前仅支持 Lemon Squeezy。
    if (request.method === 'POST' && path.startsWith('/v1/license/webhooks/')) {
      return handleWebhookDispatch(request, env, path);
    }

    return json(404, { success: false, error: 'not found' });
  },
};
