import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';

if (!globalThis.crypto) {
  // @ts-expect-error Node 测试环境补齐 Workers Web Crypto。
  globalThis.crypto = webcrypto;
}

const worker = (await import('../src/index.ts')).default;
const { sha256Hex } = await import('../src/crypto.ts');

const CODE = 'HIEXT-12345-67890-ABCDE-FGHJK';

interface DeviceRecord {
  id: string;
  license_id: string;
  fingerprint: string;
  device_name: string | null;
  platform: string | null;
  activated_at: string;
  last_seen_at: string | null;
  deactivated_at: string | null;
}

class FakeStatement {
  private values: unknown[] = [];
  private readonly db: FakeDb;
  private readonly sql: string;

  constructor(db: FakeDb, sql: string) {
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

  all<T>(): Promise<{ results: T[] }> {
    return Promise.resolve({ results: this.db.all(this.sql, this.values) as T[] });
  }

  run(): Promise<{ success: boolean }> {
    this.db.run(this.sql, this.values);
    return Promise.resolve({ success: true });
  }
}

class FakeDb {
  readonly license: Record<string, unknown>;
  readonly devices: DeviceRecord[];

  constructor(
    license: Record<string, unknown>,
    devices: DeviceRecord[],
  ) {
    this.license = license;
    this.devices = devices;
  }

  prepare(sql: string): FakeStatement {
    return new FakeStatement(this, sql);
  }

  first(sql: string, values: unknown[]): unknown {
    if (sql.startsWith('SELECT * FROM licenses WHERE code_hash')) {
      return this.license.code_hash === values[0] ? this.license : null;
    }
    if (sql.startsWith('SELECT id FROM devices WHERE id')) {
      return this.devices.find(
        (device) => device.id === values[0] && device.license_id === values[1],
      ) ?? null;
    }
    throw new Error(`Unexpected first SQL: ${sql}`);
  }

  all(sql: string, values: unknown[]): unknown[] {
    if (sql.startsWith('SELECT id, fingerprint, device_name')) {
      return this.devices.filter(
        (device) => device.license_id === values[0] && device.deactivated_at === null,
      );
    }
    throw new Error(`Unexpected all SQL: ${sql}`);
  }

  run(sql: string, values: unknown[]): void {
    if (sql.startsWith('UPDATE devices SET deactivated_at = COALESCE')) {
      const device = this.devices.find(
        (item) => item.id === values[1] && item.license_id === values[2],
      );
      if (device && device.deactivated_at === null) device.deactivated_at = String(values[0]);
      return;
    }
    throw new Error(`Unexpected run SQL: ${sql}`);
  }
}

async function fixture(status = 'active') {
  const codeHash = await sha256Hex(CODE);
  const db = new FakeDb(
    {
      id: 'license-1', code_hash: codeHash, tier: 'pro', status,
      max_devices: 3, email: 'buyer@example.com', order_id: null,
      issued_by: 'manual', issued_at: '2026-07-01T00:00:00.000Z',
      expires_at: null, meta: null,
    },
    [
      {
        id: 'device-current', license_id: 'license-1', fingerprint: 'fp-current',
        device_name: '工作电脑', platform: 'linux', activated_at: '2026-07-01T00:00:00.000Z',
        last_seen_at: '2026-07-15T00:00:00.000Z', deactivated_at: null,
      },
      {
        id: 'device-old', license_id: 'license-1', fingerprint: 'fp-old',
        device_name: '旧电脑', platform: 'windows', activated_at: '2026-06-01T00:00:00.000Z',
        last_seen_at: '2026-06-30T00:00:00.000Z', deactivated_at: null,
      },
      {
        id: 'device-released', license_id: 'license-1', fingerprint: 'fp-released',
        device_name: '已释放', platform: 'macos', activated_at: '2026-05-01T00:00:00.000Z',
        last_seen_at: null, deactivated_at: '2026-06-01T00:00:00.000Z',
      },
      {
        id: 'foreign-device', license_id: 'license-2', fingerprint: 'fp-foreign',
        device_name: '其他授权设备', platform: 'linux', activated_at: '2026-07-01T00:00:00.000Z',
        last_seen_at: null, deactivated_at: null,
      },
    ],
  );
  const counts = new Map<string, string>();
  const env = {
    DB: db,
    RATE_LIMIT_KV: {
      get: async (key: string) => counts.get(key) ?? null,
      put: async (key: string, value: string) => { counts.set(key, value); },
    },
    ADMIN_TOKEN: 'admin', ED25519_PRIVATE_KEY: '', ED25519_PUBLIC_KEY: '',
  };
  return { db, env };
}

async function post(env: unknown, path: string, body: unknown): Promise<Response> {
  return worker.fetch(new Request(`https://api.example.test${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'cf-connecting-ip': '203.0.113.10' },
    body: JSON.stringify(body),
  }), env as any);
}

test('device list only returns active devices and never exposes fingerprints', async () => {
  const { env } = await fixture();
  const response = await post(env, '/v1/license/devices/list', {
    code: CODE, currentFingerprint: 'fp-current',
  });
  assert.equal(response.status, 200);
  const body = await response.json() as any;
  assert.equal(body.maxDevices, 3);
  assert.equal(body.activeDevices, 2);
  assert.deepEqual(body.devices.map((item: any) => item.id), ['device-current', 'device-old']);
  assert.equal(body.devices[0].isCurrent, true);
  assert.equal(body.devices[1].isCurrent, false);
  assert.ok(body.devices.every((item: any) => !Object.hasOwn(item, 'fingerprint')));
});

test('device list rejects invalid and inactive license codes with stable errors', async () => {
  const active = await fixture();
  const invalid = await post(active.env, '/v1/license/devices/list', { code: 'bad' });
  assert.equal(invalid.status, 400);
  assert.equal((await invalid.json() as any).error, 'invalid code format');

  const inactive = await fixture('refunded');
  const forbidden = await post(inactive.env, '/v1/license/devices/list', { code: CODE });
  assert.equal(forbidden.status, 403);
  assert.equal((await forbidden.json() as any).error, 'license not active');
});

test('device release checks ownership and is idempotent', async () => {
  const { db, env } = await fixture();
  const foreign = await post(env, '/v1/license/devices/deactivate', {
    code: CODE, deviceId: 'foreign-device',
  });
  assert.equal(foreign.status, 404);
  assert.equal((await foreign.json() as any).error, 'device not found');

  for (let attempt = 0; attempt < 2; attempt++) {
    const released = await post(env, '/v1/license/devices/deactivate', {
      code: CODE, deviceId: 'device-old',
    });
    assert.equal(released.status, 200);
    assert.deepEqual(await released.json(), {
      success: true, deactivatedDeviceId: 'device-old',
    });
  }
  assert.ok(db.devices.find((item) => item.id === 'device-old')?.deactivated_at);
});
