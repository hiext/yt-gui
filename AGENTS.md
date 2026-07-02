# Repository Guidelines

## 项目结构与模块组织
这是一个 Flutter 桌面应用。`lib/app` 放应用入口与壳层，`lib/core` 放控制器、模型和服务，`lib/features` 按业务拆分页面（`home`、`downloads`、`history`、`settings`、`help`），`lib/shared` 放复用组件与工具函数。多语言资源在 `lib/l10n`，平台打包目录在 `linux/`、`macos/`、`windows/`。内置 `yt-dlp` 与 `ffmpeg` 二进制放在 `assets/bin/<platform>/`。测试目录 `test/` 与 `lib/` 结构保持镜像。

## 构建、测试与开发命令
- `flutter pub get`：安装依赖。
- `flutter analyze --no-fatal-infos`：执行与 CI 对齐的静态检查。
- `flutter test`：运行全部测试。
- `flutter test test/features/home/home_page_test.dart`：只运行单个页面或模块测试。
- `flutter run -d macos` / `-d linux` / `-d windows`：本地启动桌面应用。
- `flutter build macos` / `linux` / `windows`：生成发布产物。

## 代码风格与命名约定
统一使用 2 空格缩进，并遵循 `analysis_options.yaml` 中启用的 `flutter_lints`。文件名使用 `snake_case.dart`，类与枚举使用 `UpperCamelCase`，方法、变量与测试描述使用 `lowerCamelCase`。优先按功能目录放置页面与组件；通用执行器、仓储、解析器放在 `lib/core/services`。只编辑 `lib/l10n/*.arb`，不要手改生成的 `app_localizations_*.dart`。

## 测试指南
测试文件使用 `_test.dart` 后缀，并与源码路径对应，例如 `lib/core/services/yt_dlp_session.dart` 对应 `test/core/services/yt_dlp_session_test.dart`。优先覆盖下载调度、进度解析、持久化、控制器状态流转和关键页面交互。提交前至少运行 `flutter test`；修改单一模块时，先跑对应测试再跑全量。

## 提交与 Pull Request 规范
提交历史采用 Conventional Commits，常见形式如 `feat(i18n): ...`、`fix(test): ...`、`refactor(db): ...`、`ci: ...`。每次提交聚焦单一改动面，标题使用祈使句并带可选 scope。PR 需要说明用户可见变化、影响平台、关联 issue 或规格文档；涉及 UI 时附截图或录屏。发起评审前确保 `flutter analyze`、`flutter test` 以及受影响平台构建通过。

## 配置与资源注意事项
不要提交个人 Cookie 文件、机器专属路径或临时二进制。`yt-dlp` 与 `ffmpeg` 解析顺序必须固定为：设置页已验证正确的路径最高优先级，其次查找系统 `PATH` 和平台常见目录，最后使用 `assets/bin/<platform>/` 下的内置工具；自定义路径必须明确验证为对应工具，至少阻止 `yt-dlp`/`ffmpeg` 填反，并在文档/UI 中要求用 `--version` 验证。使用工具时不能静默找不到工具，必须给出设置路径、系统安装或刷新内置包的明确提示。构建前通过 `tools/fetch_embedded_tools.dart` 按锁文件刷新内置工具，并保持文件名与 README 约定一致。新增界面文案时同步更新中英文 ARB，避免硬编码字符串。
