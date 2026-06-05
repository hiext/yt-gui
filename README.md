# Hiext YT GUI

yt-dlp 可视化桌面下载器，面向普通用户的图形化视频/音频下载工具。

## 免责声明

本项目仅提供基于 `yt-dlp` 和 `ffmpeg` 的下载与管理工具，不提供任何受保护内容，也不以下载、传播或获取盗版数字数据为目的。请仅在拥有合法权利或已获得明确授权的前提下使用本工具，并自行遵守相关版权法律、平台服务条款及当地法规。

## 功能

- 粘贴链接一键解析可选格式
- 多格式选择：视频、音频、不同分辨率
- 三种下载模式：串行 / 队列 / 并发
- 断点续传：暂停、恢复、取消
- 下载中实时显示进度、速度、剩余时间
- 历史记录：已完成、失败、已取消，失败任务可重试
- 设置持久化：保存目录、画质、工具路径等重启保留
- AI 切片分析：内置候选切片、外部 Python sidecar、云端大模型配置档

## 开发环境要求

- [Flutter](https://docs.flutter.dev/get-started/install) 3.24 或更高版本
- 目标平台对应的构建工具：
  - **Linux**：GTK 3、CMake、Ninja、Clang
  - **macOS**：Xcode 16+、CocoaPods
  - **Windows**：Visual Studio 2022（含 C++ 桌面开发工作负载）

安装 Flutter 后，运行以下命令检查环境：

```bash
flutter doctor
```

## yt-dlp / ffmpeg 配置

应用内置了按平台区分的 yt-dlp 和 ffmpeg 查找逻辑。

### 方式一：使用应用内置工具（推荐）

将对应平台的二进制文件放入 `assets/bin/<platform>/` 目录：

```
assets/bin/
  linux/yt-dlp
  linux/ffmpeg
  macos/yt-dlp
  macos/ffmpeg
  windows/yt-dlp.exe
  windows/ffmpeg.exe
```

然后在 `pubspec.yaml` 中确认资产声明（已默认包含）：

```yaml
flutter:
  assets:
    - assets/bin/linux/
    - assets/bin/macos/
    - assets/bin/windows/
```

### 方式二：在设置页指定自定义路径

打开应用 → 设置，在「yt-dlp 路径」和「ffmpeg 路径」输入框中填写系统中已安装的工具路径，留空则回退到内置工具。

> 自定义路径优先于内置工具。路径不存在时，启动下载会给出明确错误提示。

## AI 切片与云端模型配置

设置页的「AI 切片分析」支持三种分析来源：

- **内置本地分析**：无需配置 API Key，生成基础候选切片。
- **外部命令 / Python sidecar**：例如 `python3 tools/ai_clip_analyzer.py --yolo-model yolov8n.pt --whisper-model small`，用于接入 YOLO、Whisper 等本地模型。
- **云端大模型地址**：支持多配置档，当前内置 OpenAI、Google Gemini、Anthropic Claude、Groq、DeepSeek、通义千问 / DashScope、OpenRouter 和自定义 JSON 接口。

云端模式下，每个配置档独立保存厂商、接口地址、模型 ID 和 API Key。OpenAI-compatible 厂商会使用 `Authorization: Bearer <key>`；Gemini 会使用 `x-goog-api-key` 并支持 `{model}` endpoint 占位；Anthropic 使用 `x-api-key`。自定义接口需要返回包含 `segments` 数组的 JSON，每个切片建议包含 `startMs`、`endMs`、`title`、`summary`、`keywords`、`tags`、`confidence`、`reason`、`detections` 和 `transcripts`。

不要提交真实 API Key、Cookie 或个人账号数据。发布包只提供工具能力，AI 切片结果仍需用户确认其来源与使用权限。

## 运行与测试

```bash
# 安装依赖
flutter pub get

# 运行静态分析
flutter analyze

# 运行全部测试
flutter test

# 在 Linux 上运行应用
flutter run -d linux

# 在 macOS 上运行应用
flutter run -d macos

# 在 Windows 上运行应用
flutter run -d windows
```

## 构建发布包

```bash
# Linux (可执行文件 + 依赖库)
flutter build linux
# 产物位于 build/linux/x64/release/bundle/

# macOS (.app 包)
flutter build macos
# 产物位于 build/macos/Build/Products/Release/

# Windows (可执行文件 + DLL)
flutter build windows
# 产物位于 build/windows/x64/runner/Release/
```

### Linux 打包建议

```bash
# 创建可分发的 tar.gz
cd build/linux/x64/release/bundle
tar czf hiext-yt-gui-linux-x64.tar.gz *

# 或使用 linuxdeploy 创建 AppImage（需先安装 linuxdeploy）
# linuxdeploy --appdir AppDir --executable hiext_yt_gui --output appimage
```

### macOS 打包建议

```bash
# 创建 .dmg（需先安装 create-dmg）
# create-dmg --volname "Hiext YT GUI" build/macos/Build/Products/Release/hiext_yt_gui.app
```

### Windows 打包建议

```bash
# 使用 Inno Setup 创建安装程序
# 或直接分发 build/windows/x64/runner/Release/ 目录
```

## 发布页文案建议

Hiext YT GUI 是一个基于 `yt-dlp` 和 `ffmpeg` 的桌面下载管理工具，提供链接解析、格式选择、下载调度、断点续传和历史记录能力。

免责声明：发布包仅提供工具能力，不包含任何受版权保护的媒体资源，也不以下载、传播或获取盗版数字数据为目的。请仅在拥有合法权利或已获得明确授权时使用，并自行遵守相关版权法律、平台服务条款及当地法规。

## 项目结构

```
lib/
  app/              # 应用入口和壳（导航 + 依赖组合）
  core/
    controllers/    # ChangeNotifier 控制器
    models/         # 数据模型（DownloadSettings、DownloadTask 等）
    services/       # yt-dlp 执行器、调度器、进度解析、工具解析、持久化
  features/
    home/           # 首页：链接解析 + 格式选择
    downloads/      # 下载中列表
    history/        # 历史记录
    settings/       # 设置页
    help/           # 帮助页
  shared/
    widgets/        # 共享组件
test/               # 测试（结构与 lib/ 对应）
```

## 技术栈

- **框架**：Flutter (Dart)
- **核心工具**：yt-dlp + ffmpeg（进程调用）
- **持久化**：shared_preferences（设置）、.part / .ytdl 文件（断点续传）
- **架构**：ChangeNotifier + 依赖注入 + TDD

## License

MIT
