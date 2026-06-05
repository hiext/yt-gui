# 功能回归指南

本文档用于在功能迭代、测试包构建和发布前回归 Hiext YT GUI 的核心能力。默认以本地自动化测试为第一层保障，再用桌面冒烟覆盖真实 UI、平台包和外部工具链边界。

## 回归范围

- **下载链路**：链接解析、格式列表、任务入队、串行/队列/并发调度、暂停、恢复、取消、失败重试、历史记录。
- **工具解析**：内置 `yt-dlp` / `ffmpeg`、自定义工具路径、平台二进制清单和缺失文件提示。
- **Cookie 管理**：浏览器 Cookie 导入、站点配置持久化、过期提示和重新导入。
- **免责声明**：首次启动提示、帮助页说明、README 和 Release 模板中的发布声明。
- **AI 切片链路**：下载完成后创建后处理任务、内置候选切片、外部 Python sidecar、云端大模型配置档、结构化切片存储、搜索和时间微调。
- **平台标识与资源**：应用图标、包名、版权信息、品牌资源和平台构建产物。

## 自动化回归命令

```bash
flutter analyze --no-fatal-infos
flutter test
flutter build macos --debug
```

CI 还会在 GitHub Actions 中执行 Linux 测试，以及 Linux、macOS、Windows 三端构建。当前本机只能可靠验证 macOS 构建；Linux/Windows 最终结果以 CI 或对应平台机器为准。

## 最近一次本地回归

日期：2026-06-05

- `git diff --check`：通过。
- `flutter analyze --no-fatal-infos`：通过。
- `flutter test`：通过，`83 passed / 1 skipped`。
- `flutter build macos --debug`：通过，产物为 `build/macos/Build/Products/Debug/hiext_yt_gui.app`。
- 桌面冒烟：macOS debug 包可启动，首页与设置页可打开，bundle ID 为 `com.hiext.ytgui`。

## 功能覆盖矩阵

| 功能面 | 主要测试文件 | 回归重点 |
| --- | --- | --- |
| 下载控制器 | `test/core/controllers/download_controller_test.dart` | 解析结果、入队、状态更新、完成后触发 AI 切片任务 |
| 下载调度 | `test/core/services/download_scheduler_test.dart` | 串行、并发上限、暂停恢复、失败重试 |
| yt-dlp 执行 | `test/core/services/process_yt_dlp_executor_test.dart` | 参数生成、格式解析、自定义路径、断点续传 |
| 设置持久化 | `test/core/services/settings_repository_test.dart` | 默认值、可选字段清理、多云配置档保存读取 |
| AI 切片执行 | `test/core/services/ai_clip_analyzer_executor_test.dart` | 内置切片、sidecar manifest、云端请求、模型返回解析 |
| 切片存储检索 | `test/core/services/clip_analysis_repository_test.dart` | 切片、检测、转写、搜索索引和微调时间 |
| 页面交互 | `test/features/*_test.dart`、`test/widget_test.dart` | 导航、设置页、下载页、历史页、集成流程 |

## 手工冒烟清单

1. 启动构建产物，确认左侧导航、首页、设置页和帮助页可打开。
2. 首次启动时确认免责声明弹窗出现，点击确认后不应重复弹出。
3. 在设置页检查保存目录、默认画质、`yt-dlp` 路径、`ffmpeg` 路径可编辑并持久化。
4. 在「AI 切片分析」中切换内置、本地 sidecar、云端大模型三种提供方。
5. 新增一个云端配置档，检查厂商、配置名、Endpoint、模型 ID、API Key 字段可见；不要输入真实生产 Key 做普通冒烟。
6. 如需验证云端切片，使用测试 Key 或本地 mock endpoint，返回包含 `segments` 数组的 JSON。
7. 下载一个有合法授权的测试资源，确认下载完成后进入历史记录，并在有媒体路径时创建 AI 切片任务。
8. 打开「切片」页，确认可查看切片、搜索关键词、查看转写/标签，并可微调开始和结束时间。

## AI 切片验收要点

云端大模型配置参考自动 AI 切片项目的常见模式：厂商、模型 ID 和 API Key 分离保存。自定义接口必须返回如下结构的 JSON：

```json
{
  "segments": [
    {
      "startMs": 1000,
      "endMs": 12000,
      "title": "片段标题",
      "summary": "片段摘要",
      "keywords": ["keyword"],
      "tags": ["tag"],
      "confidence": 0.8,
      "reason": "切片原因",
      "detections": [],
      "transcripts": []
    }
  ]
}
```

结构化字段会写入本地数据库，供后续关键词检索、标签过滤和时间微调使用。

## 验证边界

- `test/core/services/smoke_test.dart` 默认跳过，因为它需要真实网络、真实 `yt-dlp` / `ffmpeg` 二进制和平台环境。
- 可用 `https://www.youtube.com/watch?v=AQB6dVt-t64` 做手工链接解析验证；该视频约 1 小时 40 分钟，最高格式体积很大，不应用作 CI、自动化下载或默认回归下载样例。
- 自动化测试不调用真实云厂商 API，也不验证真实账号 Cookie；这些场景必须用测试 Key、测试账号或本地 mock 服务验证。
- 构建通过不等于平台签名、安装器、公证或 AppImage/DMG/EXE 分发流程完成；发布前仍需按目标平台单独验证。
- 本项目只提供工具能力。回归下载流程时必须使用拥有合法权利或明确授权的测试资源。
