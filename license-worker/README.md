# Hiext License Worker

在线激活码后端 —— Cloudflare Workers + D1，支持设备绑定与 Ed25519 签名的离线宽限 token。

## 架构

- **激活模型**：在线激活 + 设备绑定。激活码明文永不入库，仅存 `sha256(code)`。
- **离线宽限**：激活成功返回 Ed25519 签名的 entitlement token（含 `exp`），App 内置公钥离线验签，断网期间照常可用（Pro 14 天 / Team 7 天）。
- **数据**：D1（SQLite）四表 —— `licenses` / `devices` / `orders` / `webhook_events`。
- **限流**：Workers KV 按 IP 计数（20 次/分钟）。

## 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/v1/license/health` | 健康检查 |
| POST | `/v1/license/activate` | `{code, fingerprint, deviceName?, platform?}` → 签名 token |
| POST | `/v1/license/validate` | `{code, fingerprint}` → 复检 + 滚动续期 token |
| POST | `/v1/license/deactivate` | `{code, fingerprint}` → 释放席位 |
| POST | `/v1/license/admin/licenses` | 生成码（Bearer ADMIN_TOKEN，明文仅返回一次） |
| GET | `/v1/license/admin/licenses/:id` | 查询状态 + 已绑定设备 |
| POST | `/v1/license/admin/licenses/:id/revoke` | 吊销 |
| POST | `/v1/license/admin/licenses/:id/refund` | 标记退款 |
| POST | `/v1/license/webhooks/:provider` | P2 预留（当前 501） |

## 部署步骤

```bash
cd license-worker
npm install

# 1. 创建 D1 数据库，把返回的 database_id 填入 wrangler.toml
wrangler d1 create hiext-license

# 2. 建表
wrangler d1 execute hiext-license --file=schema.sql --remote

# 3. 创建 KV namespace，把 id 填入 wrangler.toml
wrangler kv namespace create RATE_LIMIT_KV

# 4. 生成 Ed25519 密钥对（私钥给 Worker，公钥嵌入 App）
node -e "const c=require('crypto');const{publicKey,privateKey}=c.generateKeyPairSync('ed25519');console.log('PRIVATE (pkcs8 base64):',privateKey.export({type:'pkcs8',format:'der'}).toString('base64'));console.log('PUBLIC (spki base64):',publicKey.export({type:'spki',format:'der'}).toString('base64'));"

# 5. 设置 secrets（绝不入库）
wrangler secret put ADMIN_TOKEN
wrangler secret put ED25519_PRIVATE_KEY
wrangler secret put ED25519_PUBLIC_KEY

# 6. 绑定域名路由（在 wrangler.toml 解开 routes 注释），部署
wrangler deploy
```

## 手动发码

```bash
curl -X POST https://dp-api.hiext.com/v1/license/admin/licenses \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tier":"pro","maxDevices":3,"email":"buyer@example.com"}'
# 响应 licenses[].code 是明文码，人工发给买家（只返回这一次）
```

## 测试

```bash
npm test   # node --experimental-strip-types --test，验证码格式/hash/Ed25519 签名
```
