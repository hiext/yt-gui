# Release Workflow

## 功能说明

Tag `v*` 触发 Flutter CI 后，`publish-release` job 会收集各平台 artifact，并创建对应 tag 的 draft release。若同名 release 已存在，workflow 只会覆盖上传 draft release 的资产。

GitHub 已发布 release 可能是不可变的，不能再补传或覆盖资产。因此同名 release 已发布且缺少资产时，CI 会提前失败并列出缺失资产，而不是继续执行 `gh release upload` 后报 `Cannot upload assets to an immutable release`。

## 上线准备配置

- 必选：`publish-release` job 保持 `permissions.contents: write`，用于创建 release 和上传资产。
- 必选：发布前只推送 tag，不要提前发布同名 release。
- 可选：如果需要人工预建 release，必须保持为 draft，等待 CI 上传资产后再发布。
- 默认行为：同名 draft release 会被更新；同名已发布 release 且资产完整时跳过上传；同名已发布 release 且资产缺失时失败并提示创建新 tag 或删除后重建 draft release。

## Properties 示例

本改动不新增应用运行时 properties。

| 配置项 | 必选 | 默认行为 | 说明 |
| --- | --- | --- | --- |
| `GH_TOKEN` | 是 | `${{ github.token }}` | GitHub Actions 自动注入，用于 `gh release` 操作。 |
| `RELEASE_TAG` | 是 | `${{ github.ref_name }}` | 当前 `v*` tag 名称，用于定位 release。 |

## SQL / 上线材料

- SQL：无数据库变更。
- 上线材料：合入 workflow 后，重新发布时建议使用新的语义化 tag，例如 `v0.0.3`。
- 事故处理：若旧 tag release 已发布但没有资产，需要在 GitHub 手动删除该 release 后重建 draft，或直接创建新 tag 触发发布。
