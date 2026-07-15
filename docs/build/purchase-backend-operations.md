# 购买与授权后端上线运维

## 结论与功能范围

仓库内已闭环的能力包括：官网套餐按钮、Pro 无正式支付链接和 Team 固定使用的人工采购邮件 fallback、Lemon Squeezy Pro 已付款订单验签与严格 variant 映射、D1 原子签发、Resend 邮件发码、失败同码重试，以及买家凭激活码查看 active 设备和按设备 ID 释放席位。

仓库不能替代外部开通：Pro 正式 checkout URL、Lemon Squeezy 店铺与 Pro variant、webhook secret、自有域名/路由、Resend API key、已验证发信域名和 `orders@hiext.com` 收件处理均需运营方真实配置。默认空 checkout 时页面明确显示人工采购，不代表已经能在线付款。

## 可验收用户路径

1. 用户在 `site/pro.html` 选择 Pro 或 Team。Pro 配置 HTTPS checkout 时进入支付页，否则打开采购邮件；Team 始终打开给 `orders@hiext.com` 的预填邮件。
2. Lemon Squeezy 对已付款订单发送 `order_created`。Worker 验签、确认 `status=paid`、仅按 Pro variant ID 白名单确认买断套餐。
3. Worker 原子写入订单、授权和幂等事件，通过 Resend 把明文码发送到下单邮箱；响应不包含明文码。
4. 用户在 App 激活。换机时 App 调用 `/devices/list` 展示 active 设备，再用 `/devices/deactivate` 释放旧设备；重复释放幂等成功。
5. Resend 暂时失败时订单为 `email_failed` 且 webhook 返回 503；支付商重试时发送同一个派生码，不重复创建授权。

## 上线准备配置

### Worker properties 示例

```properties
# 必选：基础授权服务
ADMIN_TOKEN=<高熵 bearer token>
ED25519_PRIVATE_KEY=<PKCS8 base64>
ED25519_PUBLIC_KEY=<SPKI base64，与 App 内置公钥一致>
DB.database_id=<Cloudflare D1 database id>
RATE_LIMIT_KV.id=<Cloudflare KV namespace id>

# 条件必选：启用自动购买发码
WEBHOOK_SECRET=<Lemon Squeezy signing secret>
LICENSE_CODE_SECRET=<至少 32 字节随机密钥，待投递订单存在时不得轮换>
RESEND_API_KEY=<Resend API key>
# 启用 Pro 自动购买时必须配置至少一个 Pro variant
LEMONSQUEEZY_PRO_VARIANT_IDS=<id1,id2>

# 可选
LICENSE_FROM_EMAIL=HiExt <license@hiext.com>
TURNSTILE_SECRET_KEY=<管理后台二次校验；生产建议配置>

# 公开站点配置，不是 secret
site.proCheckoutUrl=https://<provider-checkout-pro>
site.salesEmail=orders@hiext.com
```

必选项缺失的默认行为：基础密钥/绑定缺失会使对应授权功能不可用；自动发码三项 secret 任一缺失时 webhook 返回 503 且不签发；Pro variant 列表为空、与保留 Team 列表重叠或订单未命中时拒绝签发；命中 Team variant 时固定返回 503 且不签发。`LICENSE_FROM_EMAIL` 默认 `HiExt <license@hiext.com>`，但该域名仍必须在 Resend 验证。Pro checkout URL 默认为空，此时站点使用人工采购邮件；脚本只接受 HTTPS，非法 URL 同样降级。Team 无论配置如何都走人工采购。

## SQL 与迁移

新环境直接执行：

```bash
cd license-worker
wrangler d1 execute hiext-license --file=schema.sql --remote
```

旧环境加唯一索引前先查重复订单：

```sql
SELECT provider, provider_order_id, COUNT(*) AS n
FROM orders
WHERE provider_order_id IS NOT NULL
GROUP BY provider, provider_order_id
HAVING COUNT(*) > 1;
```

结果必须为空，再执行 `schema.sql`。若有重复，不得直接删除：先核对 `licenses.order_id`、退款状态和收件记录，保留正确订单并人工处理重复授权。迁移后验证：

```sql
SELECT name, sql FROM sqlite_master
WHERE type = 'index' AND name = 'idx_orders_provider_order';

SELECT status, COUNT(*) FROM orders GROUP BY status;
```

## 上线步骤与验收

1. 备份 D1，完成重复订单预检并应用 schema。
2. 配置 Worker secrets/vars、D1/KV 绑定、域名路由；验证 Resend SPF/DKIM/DMARC。
3. 在支付商测试模式配置 webhook：`POST https://<api-domain>/v1/license/webhooks/lemonsqueezy`，只订阅 Pro 买断需要的订单事件。
4. 在 `site/purchase-config.js` 写入 Pro 测试 checkout HTTPS URL；不要写 secret。
5. 运行 `cd license-worker && npm test`，预期全部通过。
6. 测试非付款事件：响应 `ignored=true`，D1 不新增授权、不发邮件。
7. 完成一笔 Pro 测试付款：订单最终为 `fulfilled`，邮箱收到码，webhook 响应中没有 `code`，`orders.license_id` 能关联 `licenses.id`。
8. 模拟 Resend 失败：订单为 `email_failed`、响应 503；恢复后重投，同一订单只保留一份授权且收到同一码。
9. 用测试码验证设备列表不返回 fingerprint、只能释放本授权设备、重复释放返回 200。

生产验收完成前保持 Pro 人工采购 fallback，不得提前填入不可用 checkout URL；Team 在订阅生命周期完成前不得开放自动 checkout。

## 监控、人工恢复与风险

重点监控 `orders.status IN ('email_pending','email_failed')`、Webhook 401/422/503、Resend 拒信和 D1 写入异常。至少每日执行：

```sql
SELECT id, provider_order_id, email, tier, status, created_at
FROM orders
WHERE status IN ('email_pending', 'email_failed')
ORDER BY created_at ASC;
```

当前没有买家邮箱登录门户、订单查询/改邮箱、退款自动吊销、Team 续费/到期同步或运营后台重发页面。退款需通过现有管理员接口或 D1 SOP处理；Team 正式售卖前必须补齐订阅生命周期，否则只能作为人工合同套餐，不能把页面年费文案当作已实现续费能力。

## 回滚

应用回滚：先把 `site/purchase-config.js` 的 checkout URL 置空，恢复人工采购；再将 Lemon Squeezy webhook 暂停投递，避免旧 Worker 收到新订单。随后回滚 Worker 代码并验证 `/health`、激活和设备释放。

数据回滚：本次 schema 只新增唯一索引，无新增列。必要时执行 `DROP INDEX IF EXISTS idx_orders_provider_order;`，但通常保留该安全约束更稳妥。不得回滚或轮换 `LICENSE_CODE_SECRET` 直到所有 `email_pending`/`email_failed` 清零；不得删除已付款订单、授权或 webhook 幂等记录。回滚后人工核对暂停窗口内的支付订单并补发。
