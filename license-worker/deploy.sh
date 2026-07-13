#!/usr/bin/env bash
# Hiext License Worker — one-shot deployment to Cloudflare (dp-api.hiext.com)
# Run once per environment. Secrets are read from stdin / env, never committed.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
say() { echo -e "${GREEN}==>${NC} $*"; }
err() { echo -e "${RED}!!${NC} $*"; exit 1; }

say "Installing dependencies ..."
npm install --silent

# ── 1. D1 ──
say "Creating D1 database (if not exists) ..."
DB_INFO=$(npx wrangler d1 create hiext-license 2>&1) || true
if echo "$DB_INFO" | grep -q 'already exists'; then
  say "D1 database already exists — reusing"
else
  echo "$DB_INFO"
fi

DB_ID=$(npx wrangler d1 list --json 2>/dev/null | python3 -c "
import sys,json
for d in json.load(sys.stdin):
    if d['name']=='hiext-license': print(d['uuid']); break
" 2>/dev/null)
if [ -z "$DB_ID" ]; then
  err "Could not resolve D1 database_id. Run 'npx wrangler d1 create hiext-license' manually."
fi
say "D1 database_id = $DB_ID"
python3 -c "
import json, sys
with open('wrangler.toml','r') as f: t=f.read()
t=t.replace('REPLACE_WITH_D1_DATABASE_ID', '$DB_ID')
with open('wrangler.toml','w') as f: f.write(t)
"

# ── 2. Schema ──
say "Applying D1 schema ..."
npx wrangler d1 execute hiext-license --file=schema.sql --remote

# ── 3. KV ──
say "Creating KV namespace for rate limiting ..."
KV_INFO=$(npx wrangler kv namespace create RATE_LIMIT_KV 2>&1) || true
if echo "$KV_INFO" | grep -q 'already exists'; then
  say "KV namespace already exists — reusing"
fi

KV_ID=$(npx wrangler kv namespace list 2>/dev/null | python3 -c "
import sys,json
for ns in json.load(sys.stdin):
    if ns['title']=='RATE_LIMIT_KV': print(ns['id']); break
" 2>/dev/null)
if [ -z "$KV_ID" ]; then
  err "Could not resolve KV namespace id. Run 'npx wrangler kv namespace create RATE_LIMIT_KV' manually."
fi
say "KV namespace_id = $KV_ID"
python3 -c "
import json, sys
with open('wrangler.toml','r') as f: t=f.read()
t=t.replace('REPLACE_WITH_KV_NAMESPACE_ID', '$KV_ID')
with open('wrangler.toml','w') as f: f.write(t)
"

# ── 4. Secrets ──
say "Setting secrets (you will be prompted for values) ..."
for secret in ADMIN_TOKEN ED25519_PRIVATE_KEY ED25519_PUBLIC_KEY TURNSTILE_SECRET_KEY; do
  printf "Enter %s: " "$secret"
  read -rs value
  echo
  if [ -n "$value" ]; then
    echo "$value" | npx wrangler secret put "$secret" 2>&1
    say "$secret set"
  else
    say "$secret skipped (empty)"
  fi
done

# ── 5. Deploy ──
say "Deploying Worker ..."
npx wrangler deploy

say ""
say "Deployment complete!"
say "Verify: curl https://dp-api.hiext.com/v1/license/health"
echo ""
say "Next: Create the Turnstile widget on https://dash.cloudflare.com/"
say "  → Turnstile → Add site → Widget Mode: Managed"
say "  → Domain: hiext.com (or your admin page domain)"
say "  → Copy the sitekey into site/admin.html data-sitekey attribute"
say "  → Copy the secret key → run: echo 'YOUR_SECRET' | npx wrangler secret put TURNSTILE_SECRET_KEY"
echo ""
say "Ed25519 keypair generation (one-time):"
echo "  node -e \"const c=require('crypto');const{pub,priv}=c.generateKeyPairSync('ed25519',{publicKeyEncoding:{type:'spki',format:'der'},privateKeyEncoding:{type:'pkcs8',format:'der'}});console.log('ED25519_PRIVATE_KEY='+priv.toString('base64'));console.log('ED25519_PUBLIC_KEY='+pub.toString('base64'))\""
say "  → Paste the public key into the Flutter app (entitlement token offline verification)"
say "  → Paste the private key into wrangler secret"
