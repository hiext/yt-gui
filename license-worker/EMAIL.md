# 邮件发码方案（P2）

自动发码：**Cloudflare Email Routing 收信 + Resend 发信**，在 Worker webhook 内完成「收到付款/订单 → 生成激活码 → 邮件送达买家」的闭环。

本文件是设计文档；发信函数骨架见 [`src/email.ts`](./src/email.ts)。webhook 本身（`/v1/license/webhooks/:provider`）当前在 `src/index.ts` 中返回 `501`，属 P2 预留，暂不实现。

## 为什么这套组合

| 环节 | 选型 | 理由 |
|------|------|------|
| 收信 / 触发 | Cloudflare Email Routing | 免费，把发往 `orders@hiext.com` 的邮件路由到 Worker（Email Worker），或作为支付 webhook 的补充触发源 |
| 发信 | Resend | 免费额度 **3,000 封/月、100 封/天**，API 简洁，Workers 内一个 `fetch` 即可；支持 SPF/DKIM 域名验证，送达率好 |
| 签发 | 复用现有 admin 逻辑 | 与 `handleAdminCreateLicense` 同一套 D1 写入，明文码只在响应/邮件出现一次 |

## 架构与数据流

```
                        ┌─────────────────────────────────────────┐
  支付平台 webhook  ───▶ │  Worker: POST /v1/license/webhooks/:pp   │
  (Stripe/微信/支付宝)    │   1. 校验签名（provider secret）          │
                        │   2. 幂等：webhook_events 去重           │
  Email Routing    ───▶ │   3. 生成激活码 → 写入 D1 licenses        │
  (orders@hiext.com)    │   4. sendLicenseEmail(env, to, code, tier)│
                        │   5. 记录 orders / 发信结果               │
                        └───────────────┬─────────────────────────┘
                                        │ fetch Resend API
                                        ▼
                              买家收到含明文激活码的邮件
```

要点：

1. **幂等**：webhook 可能重投，用 `webhook_events` 表按 `provider + event_id` 去重，避免重复发码/重复发信。
2. **签名校验**：每个 provider 的 webhook secret 存为 Worker secret（如 `STRIPE_WEBHOOK_SECRET`），验签失败直接 `400`。
3. **明文码不落库**：D1 只存 `sha256(code)`；明文码仅在生成后立即用于邮件发送，发送失败则把订单标记为 `email_failed` 供人工补发（可在 `admin.html` 手动重发）。
4. **发信解耦**：`sendLicenseEmail` 不抛异常，返回 `{ ok, error }`，webhook 据此决定订单状态，不因发信失败而回滚发码。

## Resend 接入步骤

```bash
# 1. 在 Resend 控制台验证发信域名 hiext.com（配置 SPF / DKIM / DMARC DNS 记录）
# 2. 生成 API Key，写入 Worker secret（绝不提交到仓库）
wrangler secret put RESEND_API_KEY
# 3.（可选）自定义发件人
wrangler secret put LICENSE_FROM_EMAIL   # 例如 "HiExt <license@hiext.com>"
```

DNS（示例，实际值以 Resend 面板为准）：

- `SPF`：`TXT @  "v=spf1 include:resend.com ~all"`
- `DKIM`：Resend 提供的 `resend._domainkey` CNAME/TXT
- `DMARC`：`TXT _dmarc  "v=DMARC1; p=none; rua=mailto:dmarc@hiext.com"`

## Worker 内调用 Resend（示例片段）

发信封装见 `src/email.ts` 的 `sendLicenseEmail`。webhook 内的用法：

```ts
import { generateCode } from './codes';
import { sha256Hex } from './crypto';
import { sendLicenseEmail, type Tier } from './email';

async function handleOrderPaid(env: Env, order: { email: string; tier: Tier }) {
  // 1. 生成并入库（只存 hash）
  const code = generateCode();
  const codeHash = await sha256Hex(code);
  const id = crypto.randomUUID();
  await env.DB.prepare(
    'INSERT INTO licenses (id, code_hash, tier, status, max_devices, email, issued_by, issued_at) VALUES (?,?,?,?,?,?,?,?)',
  )
    .bind(id, codeHash, order.tier, 'active', order.tier === 'team' ? 10 : 3, order.email, 'webhook', new Date().toISOString())
    .run();

  // 2. 发信（明文码只在这里出现一次）
  const sent = await sendLicenseEmail(env, order.email, code, order.tier);
  if (!sent.ok) {
    // 记录 email_failed，交由 admin.html 手动补发
    console.warn('license email failed', id, sent.error);
  }
  return { id, emailed: sent.ok };
}
```

底层就是一次 `fetch` 到 `https://api.resend.com/emails`，`Authorization: Bearer <RESEND_API_KEY>`，body 含 `from / to / subject / html / text`——完整实现见 `src/email.ts`。

## 环境变量清单

| 变量 | 类型 | 用途 |
|------|------|------|
| `RESEND_API_KEY` | secret | 调用 Resend 发信，必填 |
| `LICENSE_FROM_EMAIL` | secret / var | 发件人，可选，默认 `HiExt <license@hiext.com>` |
| `ADMIN_TOKEN` | secret | 已有，手动发码鉴权 |
| `<PROVIDER>_WEBHOOK_SECRET` | secret | 各支付平台 webhook 验签，按需添加 |

## 落地顺序

1. `src/email.ts` 发信函数骨架（本次已提供）。
2. 验证 Resend 域名 + 设置 `RESEND_API_KEY`。
3. 实现 `handleWebhook`（验签 + 幂等 + 发码 + 发信），替换 `index.ts` 中的 `501` 分支。
4. `admin.html` 增加「按订单重发」入口，兜底 `email_failed`。
