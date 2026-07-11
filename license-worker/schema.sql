-- Hiext License Worker — D1 schema
-- Apply: wrangler d1 execute hiext-license --file=schema.sql

CREATE TABLE IF NOT EXISTS licenses (
  id TEXT PRIMARY KEY,                       -- uuid v4
  code_hash TEXT NOT NULL UNIQUE,            -- sha256(code), never store plaintext
  tier TEXT NOT NULL,                        -- 'pro' | 'team'
  status TEXT NOT NULL DEFAULT 'active',     -- active | revoked | refunded
  max_devices INTEGER NOT NULL DEFAULT 1,
  email TEXT,
  order_id TEXT,
  issued_by TEXT NOT NULL DEFAULT 'manual',  -- manual | webhook
  issued_at TEXT NOT NULL,
  expires_at TEXT,                           -- Team subscription end; Pro = NULL
  meta TEXT
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,                        -- uuid v4
  license_id TEXT NOT NULL REFERENCES licenses(id),
  fingerprint TEXT NOT NULL,
  device_name TEXT,
  platform TEXT,
  activated_at TEXT NOT NULL,
  last_seen_at TEXT,
  deactivated_at TEXT,
  UNIQUE(license_id, fingerprint)
);
CREATE INDEX IF NOT EXISTS idx_devices_license ON devices(license_id);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,                     -- manual | stripe | lemonsqueezy | ...
  provider_order_id TEXT,
  email TEXT,
  tier TEXT,
  amount INTEGER,                             -- minor units (cents/fen)
  currency TEXT,
  status TEXT,
  license_id TEXT,
  raw TEXT,
  created_at TEXT NOT NULL
);

-- P2 reserved: webhook idempotency
CREATE TABLE IF NOT EXISTS webhook_events (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  provider_event_id TEXT NOT NULL,
  event_type TEXT,
  payload TEXT,
  processed INTEGER NOT NULL DEFAULT 0,
  received_at TEXT NOT NULL,
  UNIQUE(provider, provider_event_id)
);
