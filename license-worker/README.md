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
| POST | `/v1/license/devices/list` | `{code, currentFingerprint?}` → 仅列出当前 active 设备，不返回 fingerprint |
| POST | `/v1/license/devices/deactivate` | `{code, deviceId}` → 按设备 ID 幂等释放席位 |
| POST | `/v1/license/admin/licenses` | 生成码（Bearer ADMIN_TOKEN，明文仅返回一次） |
| GET | `/v1/license/admin/licenses/:id` | 查询状态 + 已绑定设备 |
| POST | `/v1/license/admin/licenses/:id/revoke` | 吊销 |
| POST | `/v1/license/admin/licenses/:id/refund` | 标记退款 |
| POST | `/v1/license/webhooks/lemonsqueezy` | 验签并仅处理已付款 `order_created`，仅按 Pro variant ID 白名单发码并通过 Resend 投递，Team 自动订单返回 503 |

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

# 自动购买发码启用时额外设置；缺任一项时 webhook 返回 503，不签发
wrangler secret put WEBHOOK_SECRET
wrangler secret put LICENSE_CODE_SECRET
wrangler secret put RESEND_API_KEY
# 另配置 LEMONSQUEEZY_PRO_VARIANT_IDS；Team variant 必须保持未配置

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
# Team 人工签发必须额外传入未来的 ISO-8601 expiresAt；缺失、无效或已过期会返回 400。
```

## 自动发码边界

- 当前只实现 Lemon Squeezy；Stripe、微信、支付宝和 Email Routing 未实现，不能只改路径名冒充支持。
- 只有验签通过、`meta.event_name=order_created`、订单状态为 `paid` 且 variant ID 命中 Pro 显式白名单时才签发；Team 自动订单固定返回 503。
- Webhook 响应不返回激活码。明文码仅发送到买家邮箱，D1 只存 hash。
- Resend 暂时失败时订单标记为 `email_failed` 并返回 503；支付商重试会派生同一个码再次投递，不重复创建授权。
- Pro 正式 checkout URL、支付商密钥、域名和 Resend 发信域名都属于外部上线配置，仓库默认不代表已开通。

## 测试

```bash
npm test   # 包含设备管理、付款事件过滤、幂等发码、邮件失败重试和响应防泄漏
```
