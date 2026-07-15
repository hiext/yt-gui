# Release Workflow

## 功能说明

Tag `v*` 触发 Flutter CI 后，`publish-release` job 会收集各平台 artifact，并创建对应 tag 的 draft release。若同名 release 已存在，workflow 只会覆盖上传 draft release 的资产。

GitHub 已发布 release 可能是不可变的，不能再补传或覆盖资产。因此同名 release 已发布且缺少资产时，CI 会提前失败并列出缺失资产，而不是继续执行 `gh release upload` 后报 `Cannot upload assets to an immutable release`。

Linux `.deb` 使用 GTK 应用 ID `com.hiext.ytgui` 作为 desktop entry 和图标名称。打包时会将 desktop entry 安装到 `/usr/share/applications/com.hiext.ytgui.desktop`，将品牌 SVG 安装到 `/usr/share/icons/hicolor/scalable/apps/com.hiext.ytgui.svg`，确保应用菜单、任务栏和运行窗口能够关联到同一个图标。

## 上线准备配置

- 必选：`publish-release` job 保持 `permissions.contents: write`，用于创建 release 和上传资产。
- 必选：发布前只推送 tag，不要提前发布同名 release。
- 必选：保留 `linux/packaging/com.hiext.ytgui.desktop` 与 `linux/CMakeLists.txt` 中 `APPLICATION_ID` 一致。
- 必选：保留 `assets/branding/hiext-yt-logo-mark.svg`，Linux `.deb` 打包会将其安装到系统图标主题目录。
- 可选：如果需要人工预建 release，必须保持为 draft，等待 CI 上传资产后再发布。
- 默认行为：Linux 打包会使用 `desktop-file-validate` 校验 desktop entry，并检查 `.deb` 内包含 desktop entry 与图标；任一文件缺失时构建失败。
- 默认行为：同名 draft release 会被更新；同名已发布 release 且资产完整时跳过上传；同名已发布 release 且资产缺失时失败并提示创建新 tag 或删除后重建 draft release。

## Properties 示例

本改动不新增应用运行时 properties。

| 配置项 | 必选 | 默认行为 | 说明 |
| --- | --- | --- | --- |
| `GH_TOKEN` | 是 | `${{ github.token }}` | GitHub Actions 自动注入，用于 `gh release` 操作。 |
| `RELEASE_TAG` | 是 | `${{ github.ref_name }}` | 当前 `v*` tag 名称，用于定位 release。 |
| `APP_ID` | 是 | `com.hiext.ytgui` | Linux desktop entry、图标名与 GTK 应用 ID。 |

## SQL / 上线材料

- SQL：无数据库变更。
- 上线材料：合入 workflow 后，重新发布时建议使用新的语义化 tag，例如 `v0.0.4`。
- Linux 验收：安装新 `.deb` 后确认应用菜单和任务栏显示品牌图标；可用 `dpkg -L hiext-yt-gui | grep -E 'applications|icons/hicolor'` 核对安装文件。
- Linux 升级：旧版 `hiext-yt-gui.desktop` 不再由新包安装；测试机若曾手工创建同名文件，应删除该手工文件，避免桌面环境显示重复入口。
- 事故处理：若旧 tag release 已发布但没有资产，需要在 GitHub 手动删除该 release 后重建 draft，或直接创建新 tag 触发发布。
