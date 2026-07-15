# 链接解析固定 120 秒延迟 RCA

## 问题现象

配置了匹配站点的 Cookie 后，公共链接可能长期显示“正在解析”，约 120 秒后才正常展示格式列表。部分场景即使 yt-dlp 主进程已经退出，也会因为其子进程继承 stdout/stderr 管道而持续等待。

## 调用链

1. `HomePage._inspect` 设置解析中状态并等待 controller。
2. `DownloadController.inspect` 透传当前下载设置。
3. `ProcessYtDlpExecutor.inspect` 解析 Cookie、启动 yt-dlp，并等待进程与输出流。
4. `YtDlpSession` 只消费进程输出，不设置 120 秒超时。

因此固定 120 秒来自 `ProcessYtDlpExecutor`，不在 UI、controller 或 session。

## RCA

### 5-Why

1. 为什么用户总在约 120 秒后才看到结果？
   首次解析达到硬编码 120 秒超时后，执行器又发起第二次解析，第二次成功。
2. 为什么首次解析会固定等待 120 秒？
   有匹配 Cookie 时旧逻辑总是先带 Cookie 解析；过期或异常 Cookie、卡住的 extractor 会一直等到进程超时。
3. 为什么超时后还能正常解析？
   旧逻辑捕获所有 `YtDlpExecutorException`，包括超时，然后自动改为不带 Cookie 重试。
4. 为什么生产进程可能超时后仍残留？
   生产分支使用 `Process.run(...).timeout(...)`；Future 超时只停止等待，代码拿不到 `Process` 句柄来终止底层进程。
5. 为什么现有测试没有阻止回归？
   注入假进程的测试走 `Process.start` 风格分支，生产默认 runner 却走 `Process.run` 分支，生产与测试的超时和清理行为不一致。

### 根因结论

根因是“Cookie 优先 + 每轮 120 秒 + 超时也自动回退”的重试策略，以及生产/测试使用不同进程管理路径。固定 120 秒不是 UI 定时器，也不是 JSON 解析性能问题。

## 修复方案

- 公共无 Cookie 解析优先；成功时只启动一个进程。
- 无 Cookie 快速非零退出且存在匹配 Cookie 时，才带 Cookie 重试。
- 无 Cookie 已超时时直接报错，不再叠加第二个 120 秒。
- 生产与测试统一通过 `Process.start` runner 获取进程句柄。
- 真实超时发送 `SIGKILL`，并对终止确认和 stdout/stderr 清理设置有界等待。
- 主进程已退出但输出流不关闭时，在清理时限后使用已收集的完整 JSON，避免永久等待。

## 影响范围

- 代码：仅链接解析执行器及其单元测试。
- 平台：Linux、macOS、Windows 共用 Dart 执行器逻辑。
- 用户：公共链接解析更快；需要登录态的链接仍会在公共访问快速失败后使用已配置 Cookie。
- 不受影响：下载参数、下载重试、授权/购买、数据库、yt-dlp/ffmpeg 查找优先级。

工具查找优先级保持不变：设置页已验证路径 > 系统 `PATH` 和平台常见目录 > `assets/bin/<platform>/` 内置工具。缺失工具仍返回设置路径、系统安装或刷新内置包的明确提示。

## 上线准备与配置

无需新增环境变量、properties 或远程配置。内部默认行为：

- 单次解析超时：120 秒。
- 超时后的进程退出确认和流清理等待：10 秒，各自有界。
- Cookie 策略：公共访问优先；仅快速失败后尝试匹配且启用的 Cookie；超时不重试。

发布前：

1. 按锁文件执行 `dart run tools/fetch_embedded_tools.dart` 刷新内置工具。
2. 执行 `flutter analyze --no-fatal-infos`。
3. 执行 `flutter test`，至少包含 `test/core/services/process_yt_dlp_executor_test.dart`。
4. 在受影响桌面平台用公共链接和登录态链接各做一次冒烟解析。
5. 观察调试日志中的 `inspect: exitCode`、`stream drain timed out` 和 Cookie 重试记录。

## properties 示例

```properties
# 必选：无
# 可选：无
# 默认行为：解析超时 120 秒，清理等待 10 秒。
# 默认行为：公共无 Cookie 解析优先；仅快速非零失败后使用匹配 Cookie。
# 说明：当前版本不从 properties 读取上述内部时限，请勿添加未实现的键。
```

## SQL / 上线材料

- SQL：无。没有数据库表、索引或数据迁移。
- 配置变更：无。
- 密钥与 Cookie 迁移：无。
- 回滚：回滚执行器与对应测试即可；不涉及数据回滚。

## 回归覆盖

- 配置 Cookie 时，公共解析快速成功且只启动一次。
- 公共解析快速非零失败后，带 Cookie 重试并成功。
- 公共解析真实超时时终止进程，且不再进行 Cookie 二次超时。
- 主进程退出但输出流不关闭时，有界等待后使用已收集输出。
- 原有非零退出、日志透传、工具路径优先级和格式解析测试继续通过。

## 本地验证记录

- `flutter test test/core/services/process_yt_dlp_executor_test.dart`：21 个测试全部通过。
- `flutter test test/core/controllers/download_controller_test.dart test/features/home/home_page_test.dart`：15 个测试全部通过。
- `flutter analyze --no-fatal-infos lib/core/services/process_yt_dlp_executor.dart test/core/services/process_yt_dlp_executor_test.dart`：No issues found。
