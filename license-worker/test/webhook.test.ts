import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';

if (!globalThis.crypto) {
  // @ts-expect-error Node 测试环境补齐 Workers Web Crypto。
  globalThis.crypto = webcrypto;
}

const worker = (await import('../src/index.ts')).default;
const { parseLemonSqueezyPaidOrder } = await import('../src/webhook.ts');

interface StoredOrder {
  id: string;
  provider: string;
  provider_order_id: string;
  status: string;
  license_id: string;
}

interface StoredLicense {
  id: string;
  code_hash: string;
}

interface StoredWebhook {
  provider: string;
  provider_event_id: string;
  processed: number;
}

class FakeStatement {
  values: unknown[] = [];
  readonly sql: string;
  private readonly db: FakeWebhookDb;

  constructor(db: FakeWebhookDb, sql: string) {
    this.db = db;
    this.sql = sql;
  }

  bind(...values: unknown[]): this {
    this.values = values;
    return this;
  }

  first<T>(): Promise<T | null> {
    return Promise.resolve(this.db.first(this.sql, this.values) as T | null);
  }

  run(): Promise<{ success: boolean }> {
    this.db.run(this.sql, this.values);
    return Promise.resolve({ success: true });
  }
}

class FakeWebhookDb {
  readonly orders: StoredOrder[] = [];
  readonly licenses: StoredLicense[] = [];
  readonly webhooks: StoredWebhook[] = [];

  prepare(sql: string): FakeStatement {
    return new FakeStatement(this, sql);
  }

  async batch(statements: FakeStatement[]): Promise<unknown[]> {
    statements.forEach((statement) => this.run(statement.sql, statement.values));
    return statements.map(() => ({ success: true }));
  }

  first(sql: string, values: unknown[]): unknown {
    if (sql.startsWith('SELECT processed FROM webhook_events')) {
      return this.webhooks.find(
        (item) => item.provider === values[0] && item.provider_event_id === values[1],
      ) ?? null;
    }
    if (sql.startsWith('SELECT o.id, o.license_id')) {
      const order = this.orders.find(
        (item) => item.provider === values[0] && item.provider_order_id === values[1],
      );
      const license = this.licenses.find((item) => item.id === order?.license_id);
      return order && license
        ? { id: order.id, license_id: order.license_id, status: order.status, code_hash: license.code_hash }
        : null;
    }
    throw new Error(`Unexpected first SQL: ${sql}`);
  }

  run(sql: string, values: unknown[]): void {
    if (sql.startsWith('INSERT INTO orders')) {
      this.orders.push({
        id: String(values[0]), provider: String(values[1]),
        provider_order_id: String(values[2]), status: String(values[7]),
        license_id: String(values[8]),
      });
      return;
    }
    if (sql.startsWith('INSERT INTO licenses')) {
      this.licenses.push({ id: String(values[0]), code_hash: String(values[1]) });
      return;
    }
    if (sql.startsWith('INSERT INTO webhook_events')) {
      this.webhooks.push({
        provider: String(values[1]), provider_event_id: String(values[2]), processed: 1,
      });
      return;
    }
    if (sql.startsWith('UPDATE orders SET status')) {
      const order = this.orders.find((item) => item.id === values[1]);
      if (order) order.status = String(values[0]);
      return;
    }
    throw new Error(`Unexpected run SQL: ${sql}`);
  }
}

function payload(eventType = 'order_created', variantId = 'pro-variant', status = 'paid'): string {
  return JSON.stringify({
    meta: { event_name: eventType },
    data: {
      id: 'order-1001',
      attributes: {
        status,
        user_email: 'Buyer@Example.com',
        total: 12800,
        currency: 'cny',
        first_order_item: { variant_id: variantId, variant_name: 'Team name is untrusted' },
      },
    },
  });
}

async function sign(rawBody: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody)),
  );
  return Array.from(signature).map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function env(db: FakeWebhookDb) {
  const counts = new Map<string, string>();
  return {
    DB: db,
    RATE_LIMIT_KV: {
      get: async (key: string) => counts.get(key) ?? null,
      put: async (key: string, value: string) => { counts.set(key, value); },
    },
    ADMIN_TOKEN: 'admin', ED25519_PRIVATE_KEY: '', ED25519_PUBLIC_KEY: '',
    WEBHOOK_SECRET: 'webhook-secret',
    LICENSE_CODE_SECRET: '0123456789abcdef0123456789abcdef',
    RESEND_API_KEY: 'resend-key', LEMONSQUEEZY_PRO_VARIANT_IDS: 'pro-variant',
    LEMONSQUEEZY_TEAM_VARIANT_IDS: 'team-variant',
  };
}

async function dispatch(workerEnv: unknown, rawBody: string): Promise<Response> {
  return worker.fetch(new Request('https://api.example.test/v1/license/webhooks/lemonsqueezy', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'cf-connecting-ip': '198.51.100.9',
      'x-signature': await sign(rawBody, 'webhook-secret'),
    },
    body: rawBody,
  }), workerEnv as any);
}

test('manual Team issuance requires a future expiry', async () => {
  const response = await worker.fetch(new Request(
    'https://api.example.test/v1/license/admin/licenses',
    {
      method: 'POST',
      headers: {
        authorization: 'Bearer admin',
        'content-type': 'application/json',
      },
      body: JSON.stringify({ tier: 'team', email: 'buyer@example.test' }),
    },
  ), env(new FakeWebhookDb()) as any);
  assert.equal(response.status, 400);
  assert.equal(
    (await response.json() as any).error,
    'team expiresAt must be a future ISO-8601 timestamp',
  );
});

test('parser ignores non-payment events and never guesses tier from variant name', () => {
  const ignored = parseLemonSqueezyPaidOrder(payload('subscription_updated'), 'pro-variant', 'team-variant');
  assert.deepEqual(ignored, { kind: 'ignored', eventType: 'subscription_updated' });

  const parsed = parseLemonSqueezyPaidOrder(payload(), 'pro-variant', 'team-variant');
  assert.equal(parsed.kind, 'paid');
  if (parsed.kind === 'paid') assert.equal(parsed.event.tier, 'pro');

  const unpaid = parseLemonSqueezyPaidOrder(payload('order_created', 'pro-variant', 'pending'), 'pro-variant', 'team-variant');
  assert.deepEqual(unpaid, { kind: 'error', status: 422, error: 'order is not paid' });
  const unmapped = parseLemonSqueezyPaidOrder(payload('order_created', 'other'), 'pro-variant', 'team-variant');
  assert.deepEqual(unmapped, { kind: 'error', status: 422, error: 'unmapped variant' });
  const team = parseLemonSqueezyPaidOrder(payload('order_created', 'team-variant'), 'pro-variant', 'team-variant');
  assert.deepEqual(team, {
    kind: 'error',
    status: 503,
    error: 'team billing lifecycle not supported',
  });
});

test('Team order is rejected without issuing a license or sending email', async () => {
  const db = new FakeWebhookDb();
  let emailCalls = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { emailCalls += 1; return Response.json({ id: 'email-team' }); };
  try {
    const response = await dispatch(env(db), payload('order_created', 'team-variant'));
    assert.equal(response.status, 503);
    assert.equal((await response.json() as any).error, 'team billing lifecycle not supported');
    assert.equal(db.licenses.length, 0);
    assert.equal(db.orders.length, 0);
    assert.equal(emailCalls, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('non-payment webhook is acknowledged without issuing a license or sending email', async () => {
  const db = new FakeWebhookDb();
  let emailCalls = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => { emailCalls += 1; return new Response('{}', { status: 200 }); };
  try {
    const response = await dispatch(env(db), payload('subscription_updated'));
    assert.equal(response.status, 200);
    assert.equal((await response.json() as any).ignored, true);
    assert.equal(db.licenses.length, 0);
    assert.equal(emailCalls, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('paid webhook emails the code, persists one linked license, and never exposes code in response', async () => {
  const db = new FakeWebhookDb();
  const deliveredCodes: string[] = [];
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    const body = JSON.parse(String(init?.body)) as { text: string };
    deliveredCodes.push(body.text.match(/HIEXT-[0-9A-HJKMNP-TV-Z-]+/)?.[0] ?? '');
    return Response.json({ id: 'email-1' });
  };
  try {
    const workerEnv = env(db);
    const response = await dispatch(workerEnv, payload());
    assert.equal(response.status, 200);
    const responseBody = await response.json() as any;
    assert.equal(responseBody.emailDelivered, true);
    assert.ok(!Object.hasOwn(responseBody, 'code'));
    assert.equal(db.licenses.length, 1);
    assert.equal(db.orders[0].license_id, db.licenses[0].id);
    assert.equal(db.orders[0].status, 'fulfilled');
    assert.match(deliveredCodes[0], /^HIEXT-/);

    workerEnv.LICENSE_CODE_SECRET = 'fedcba9876543210fedcba9876543210';
    const retry = await dispatch(workerEnv, payload());
    assert.equal(retry.status, 200);
    assert.equal((await retry.json() as any).alreadyProcessed, true);
    assert.equal(deliveredCodes.length, 1);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('email failure returns 503 and retry sends the same code without issuing twice', async () => {
  const db = new FakeWebhookDb();
  const deliveredCodes: string[] = [];
  let attempts = 0;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (_input, init) => {
    attempts += 1;
    const body = JSON.parse(String(init?.body)) as { text: string };
    deliveredCodes.push(body.text.match(/HIEXT-[0-9A-HJKMNP-TV-Z-]+/)?.[0] ?? '');
    return attempts === 1 ? new Response('temporary failure', { status: 503 }) : Response.json({ id: 'email-2' });
  };
  try {
    const workerEnv = env(db);
    assert.equal((await dispatch(workerEnv, payload())).status, 503);
    assert.equal(db.orders[0].status, 'email_failed');
    assert.equal((await dispatch(workerEnv, payload())).status, 200);
    assert.equal(db.orders[0].status, 'fulfilled');
    assert.equal(db.licenses.length, 1);
    assert.equal(deliveredCodes[0], deliveredCodes[1]);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
