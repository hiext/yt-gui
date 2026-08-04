# 邮件发码实现与运营边界

Pro 自动发码使用 **Lemon Squeezy webhook + Resend 发信**，在 Worker 内完成「确认已付款订单 → 签发激活码 → 邮件投递」。Cloudflare Email Routing、Stripe、微信和支付宝尚未实现。

真实实现位于 `src/index.ts`、`src/webhook.ts` 和 `src/email.ts`。是否可上线仍取决于支付商 checkout、webhook secret、variant ID、Resend 密钥和已验证发信域名；这些外部配置未提交到仓库。

## 为什么这套组合

| 环节 | 选型 | 理由 |
|------|------|------|
| 付款触发 | Lemon Squeezy webhook | 使用原始请求体 HMAC 验签，只接收 `paid` 的 `order_created` |
| 发信 | Resend | 免费额度 **3,000 封/月、100 封/天**，API 简洁，Workers 内一个 `fetch` 即可；支持 SPF/DKIM 域名验证，送达率好 |
| 签发 | D1 原子批量写入 | 订单、授权、幂等事件同时落库；明文码不入库，也不在 webhook 响应出现 |

## 架构与数据流

```
                        ┌─────────────────────────────────────────┐
  Lemon Squeezy webhook ─▶│  POST /v1/license/webhooks/lemonsqueezy│
                        │   1. 校验签名与 paid 订单状态             │
                        │   2. 幂等：webhook_events 去重           │
                        │   3. 仅按 Pro variant ID 白名单映射买断套餐         │
                        │   4. 派生激活码 → 原子写入 D1             │
                        │   5. 记录 orders / 发信结果               │
                        └───────────────┬─────────────────────────┘
                                        │ fetch Resend API
                                        ▼
                              买家收到含明文激活码的邮件
```

要点：

1. **事件过滤**：非 `order_created` 事件返回 `ignored`，未付款、未知/Team variant 或缺配置均不会签发。
2. **幂等**：`webhook_events` 按 provider + 事件键去重，D1 `batch` 原子写入订单、授权和事件。
3. **重试不换码**：用 `LICENSE_CODE_SECRET` 对稳定订单事件键做 HMAC 派生；Resend 失败后支付商重试会发送同一个码，不保存明文。
4. **投递状态**：订单依次为 `email_pending`、`fulfilled` 或 `email_failed`。`email_failed` 返回 503 触发支付商重试；同一封邮件可能按“至少一次”语义重复到达，但内容是同一个码。
5. **密钥轮换限制**：存在 `email_pending`/`email_failed` 订单时不得轮换 `LICENSE_CODE_SECRET`，否则 Worker 会检测 hash 不一致并拒绝发送。

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

## Worker 内调用 Resend

`src/index.ts` 在原子签发后调用 `sendLicenseEmail`。底层向 `https://api.resend.com/emails` 发送 `from / to / subject / html / text`；只有 Resend 返回成功才把订单更新为 `fulfilled`。支付商响应只含 `emailDelivered` 等状态，不含激活码。

## 环境变量清单

| 变量 | 类型 | 用途 |
|------|------|------|
| `RESEND_API_KEY` | secret | 调用 Resend 发信，必填 |
| `WEBHOOK_SECRET` | secret | Lemon Squeezy 原始请求体 HMAC 验签，必填 |
| `LICENSE_CODE_SECRET` | secret | 稳定派生 webhook 激活码，必填且不可随意轮换 |
| `LEMONSQUEEZY_PRO_VARIANT_IDS` | var / secret | Pro variant ID 逗号列表，至少一档必须配置 |
| `LEMONSQUEEZY_TEAM_VARIANT_IDS` | 保留防护项 | 必须保持未配置；即使命中也返回 503，不签发 |
| `LICENSE_FROM_EMAIL` | secret / var | 发件人，可选，默认 `HiExt <license@hiext.com>` |
| `ADMIN_TOKEN` | secret | 已有，手动发码鉴权 |

## 上线门槛

1. 配置真实 Pro checkout URL、Lemon Squeezy Pro variant ID 与 webhook 地址。
2. 验证 Resend 发信域名并设置全部必选 secret。
3. 先用支付商测试订单验证 D1 状态、收件箱与 webhook 响应不含 `code`。
4. 配置 `email_failed` 监控和人工处理 SOP；仓库当前没有订单重发管理页面，不能宣称运营侧已完全自助。Team 只允许人工采购，并必须按未来 `expiresAt` 签发。
