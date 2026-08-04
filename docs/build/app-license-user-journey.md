# App 授权购买与设备管理闭环

## 结论

App 端授权路径已补齐为“选择套餐并购买 → 邮件查收激活码 → App 激活 → 刷新授权 → 查看/释放设备”。客户端不实现支付，也不虚构支付接口；仅 Pro 正式购买地址由构建配置注入，未配置或非法时降级为 `orders@hiext.com` 邮件采购。Team 在续费、取消与退款生命周期闭环前固定走人工邮件采购。

## 功能说明

### 用户路径

1. 打开“授权”页，对比 Free、Pro、Team 权益。
2. 点击“购买 Pro”或“购买 Team”。
   - Pro 已配置正式购买 URL：使用系统浏览器打开 Pro checkout。
   - Team 固定打开系统邮件应用，由人工确认一年期限、付款与发码。
   - 未配置或不是有效 HTTPS 地址：打开系统邮件应用，收件人为 `orders@hiext.com`，主题包含套餐与平台。
3. 用户付款并从订单邮箱取得激活码，在 App 输入激活。
4. 激活后点击“刷新授权与设备”，查看激活、到期、离线宽限和设备席位。
5. 换机或席位满时，可在当前电脑释放旧设备；释放本设备后 App 回到 Free。

### 错误恢复

- 购买入口无法打开：页面展示可手动打开的完整 URL 或 `mailto` 地址。
- 在线刷新失败：保留本地授权，由离线宽限控制当前权益，并显示可重试错误。
- 释放设备失败：不清空本地授权、不删除设备列表，用户解决网络或服务问题后重试。
- 订阅已到期：仍按“持有授权”展示管理区，避免到期后无法刷新或释放席位。

## App 与授权服务契约

现有契约继续复用：

- `POST /v1/license/activate`：绑定当前设备并签发 entitlement token。
- `POST /v1/license/validate`：在线复检并滚动更新 token。
- `POST /v1/license/deactivate`：兼容的当前设备释放接口。

设备自助管理契约：

- `POST /v1/license/devices/list`
  - 请求：`{code,currentFingerprint?}`
  - 响应：`{success,maxDevices,activeDevices,devices:[{id,deviceName,platform,activatedAt,lastSeenAt,isCurrent}]}`
  - 只返回 active devices，不返回 fingerprint。
- `POST /v1/license/devices/deactivate`
  - 请求：`{code,deviceId}`
  - 响应：`{success,deactivatedDeviceId}`
  - `deviceId` 必须属于当前激活码；重复释放同一设备为幂等成功。

激活码仅放在 HTTPS JSON 请求体中，不拼到购买 URL 或查询参数。

## 上线准备配置

### properties 示例

```properties
# 条件必选：上线 Pro 在线支付时必须配置；仅采用人工邮件采购时可不填。
HIEXT_PRO_PURCHASE_URL=https://checkout.example.com/hiext-pro


# 可选：留空、未定义或不是有效 HTTPS 地址时启用默认行为。
# 默认行为：打开 mailto:orders@hiext.com，主题自动带 Pro/Team 与当前平台。
```

Flutter 不会自动读取 `.properties` 文件，发布流水线需显式传入：

```bash
flutter build linux \
  --dart-define=HIEXT_PRO_PURCHASE_URL=https://checkout.example.com/hiext-pro
```

macOS、Windows 构建使用同一 `--dart-define`。正式 URL 上线前必须验证：

1. Pro 地址使用 HTTPS 且证书有效；HTTP 会被 App 拒绝并降级到邮件采购。
2. 地址必须直达正确的 Pro checkout variant，不能是 200 状态的公司首页 fallback。
3. 使用测试订单验证 Pro 商品、价格和设备数；Team 只验收人工邮件、未来到期日和发码流程。

## SQL / 上线材料

无需 SQL。

原因：App 授权状态仍保存在现有 `license_state.data` JSON 中，新增 `maxDevices` 只增加兼容字段；设备列表实时来自授权 API，不落本地新表。授权服务复用现有 `devices` 表，新增买家接口不要求 schema 变更。

上线材料：

- 先部署包含 `/devices/list` 与 `/devices/deactivate` 的授权 Worker，再发布新 App。
- 配置并验证 Pro 正式购买 URL；Team 保持人工采购，并确认 `orders@hiext.com` 可收件并有人处理。
- 用测试订单完成一次“购买/邮件 → 收码 → 激活 → 刷新 → 释放旧设备 → 换机激活”人工验收。
- 不使用生产激活码跑普通 CI；客户端测试使用进程和 API mock。

## 影响范围

- Linux、macOS、Windows：增加系统浏览器/邮件客户端打开动作。
- 授权控制器：显式同步状态与错误，释放失败不再静默清空授权。
- 本地数据：向前兼容，无迁移；旧版本可忽略新增 JSON 字段。
- 外部依赖：Pro 正式 checkout 地址、Team 人工订单邮件处理、授权 Worker 设备接口必须由上线环境提供。
