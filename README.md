# Hiext YT GUI

yt-dlp 可视化桌面下载器，面向普通用户的图形化视频/音频下载工具。

## 免责声明

本项目仅提供基于 `yt-dlp` 和 `ffmpeg` 的下载与管理工具，不提供任何受保护内容，也不以下载、传播或获取盗版数字数据为目的。请仅在拥有合法权利或已获得明确授权的前提下使用本工具，并自行遵守相关版权法律、平台服务条款及当地法规。

## 安装指南

### 下载

从 [GitHub Actions](https://github.com/hiext/yt-gui/actions) 最新一次成功构建的 **Artifacts** 中下载对应平台的压缩包，或从 [Releases](https://github.com/hiext/yt-gui/releases) 页面下载已发布的版本。

| 平台 | Artifact 名称 | 包内容 |
|------|--------------|--------|
| Linux (x64) | `hiext-yt-gui-linux-x64` | 可执行文件 + 运行时库 |
| macOS | `hiext-yt-gui-macos` | `.app` 应用包 |
| Windows (x64) | `hiext-yt-gui-windows-x64` | 可执行文件 + DLL |

### Linux

1. 下载 `hiext-yt-gui-linux-x64` artifact 并解压：

   ```bash
   unzip hiext-yt-gui-linux-x64.zip -d hiext-yt-gui
   cd hiext-yt-gui
   ```

2. 确保系统已安装运行依赖：

   ```bash
   # Debian / Ubuntu
   sudo apt-get install -y libgtk-3-0 libnotify4 libsqlite3-0

   # Fedora
   sudo dnf install -y gtk3 libnotify sqlite

   # Arch
   sudo pacman -S --needed gtk3 libnotify sqlite
   ```

3. 赋予执行权限并运行：

   ```bash
   chmod +x hiext_yt_gui
   ./hiext_yt_gui
   ```

4. （可选）创建桌面快捷方式：

   ```bash
   mkdir -p ~/.local/share/applications
   cat > ~/.local/share/applications/hiext-yt-gui.desktop << 'EOF'
   [Desktop Entry]
   Name=Hiext YT GUI
   Comment=yt-dlp visual downloader
   Exec=/path/to/hiext-yt-gui/hiext_yt_gui
   Icon=/path/to/hiext-yt-gui/data/flutter_assets/assets/branding/hiext-yt-logo-mark.png
   Type=Application
   Categories=Utility;Video;
   EOF
   ```

   > 将 `/path/to/hiext-yt-gui` 替换为实际解压路径。

### macOS

1. 下载 `hiext-yt-gui-macos` artifact 并解压得到 `hiext_yt_gui.app`。

2. 由于应用未经过 Apple 公证，首次打开时需绕过 Gatekeeper：

   ```bash
   # 移除隔离属性
   xattr -cr hiext_yt_gui.app

   # 或右键点击 .app → 按住 Option 键 → 选择"打开"
   ```

3. 将 `hiext_yt_gui.app` 拖入 `/Applications` 文件夹即可。

4. （可选）安装 yt-dlp / ffmpeg runtime 依赖：

   ```bash
   brew install yt-dlp ffmpeg
   ```

   > 应用内置了工具查找逻辑，也可在设置 → yt-dlp/ffmpeg 路径中指定自定义路径。

### Windows

1. 下载 `hiext-yt-gui-windows-x64` artifact 并解压到目标目录。

2. 确保系统已安装 [Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)（通常已预装）。

3. 双击 `hiext_yt_gui.exe` 启动应用。

4. （可选）右键 `hiext_yt_gui.exe` → **发送到** → **桌面快捷方式**。

### 首次运行配置

首次启动后，应用会显示免责声明弹窗，阅读并确认后进入主界面。建议在**设置**页面中：

- 指定**保存目录**（默认 `~/Videos/Hiext YT GUI`）
- 如需使用自定义工具路径，可在 yt-dlp/ffmpeg 输入框中填写
- 调整下载模式（串行 / 并发）与并发数量

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

发布前运行脚本，将锁定版本的工具下载到 `assets/bin/<platform>/`：

```bash
# 查看计划下载项
dart run tools/fetch_embedded_tools.dart --dry-run

# 只准备当前 macOS 包需要的 yt-dlp
dart run tools/fetch_embedded_tools.dart --platform=macos --tool=yt-dlp

# 准备 Linux / Windows 已锁定的 yt-dlp 与 LGPL ffmpeg
dart run tools/fetch_embedded_tools.dart --platform=linux,windows
```

脚本读取 `tools/embedded_tools.lock.json`，下载后校验 SHA256，再放入对应目录：

```
assets/bin/
  linux/yt-dlp
  linux/ffmpeg
  macos/yt-dlp
  macos/ffmpeg
  windows/yt-dlp.exe
  windows/ffmpeg.exe
```

这些二进制体积较大，默认被 `.gitignore` 排除；请只提交锁文件、脚本和许可证说明。macOS 的 `ffmpeg` 目前不默认内置，发布前需先在锁文件中补充已确认许可证、签名/公证和 SHA256 的供应源，或继续使用 Homebrew / 自定义路径。

然后在 `pubspec.yaml` 中确认资产声明（已默认包含）：

```yaml
flutter:
  assets:
    - assets/bin/linux/
    - assets/bin/macos/
    - assets/bin/windows/
```

### 方式二：在设置页指定自定义路径

打开应用 → 设置，在「yt-dlp 路径」和「ffmpeg 路径」输入框中填写系统中已安装的工具路径，留空则优先使用内置工具，再回退到系统 `PATH` 和常见目录（如 `/opt/homebrew/bin`、`/usr/local/bin`）。

> 自定义路径优先于内置工具。路径不存在时，启动下载会给出明确错误提示。

### 第三方工具许可证

内置工具发布前必须同步更新 [第三方工具声明](docs/third-party-tools.md)。`yt-dlp` 使用官方 release；`ffmpeg` 优先选择 LGPL 构建，禁止在未评审的情况下打包 GPL 或 nonfree 构建。

## AI 切片与云端模型配置

设置页的「AI 切片分析」支持三种分析来源：

- **内置本地分析**：无需配置 API Key，生成基础候选切片。
- **外部命令 / Python sidecar**：例如 `python3 tools/ai_clip_analyzer.py --yolo-model yolov8n.pt --whisper-model small`，用于接入 YOLO、Whisper 等本地模型。
- **云端大模型地址**：支持多配置档，当前内置 OpenAI、Google Gemini、Anthropic Claude、Groq、DeepSeek、通义千问 / DashScope、OpenRouter 和自定义 JSON 接口。

云端模式下，每个配置档独立保存厂商、接口地址、模型 ID 和 API Key。OpenAI-compatible 厂商会使用 `Authorization: Bearer <key>`；Gemini 会使用 `x-goog-api-key` 并支持 `{model}` endpoint 占位；Anthropic 使用 `x-api-key`。自定义接口需要返回包含 `segments` 数组的 JSON，每个切片建议包含 `startMs`、`endMs`、`title`、`summary`、`keywords`、`tags`、`confidence`、`reason`、`detections` 和 `transcripts`。

不要提交真实 API Key、Cookie 或个人账号数据。发布包只提供工具能力，AI 切片结果仍需用户确认其来源与使用权限。

## 项目文档

- [功能回归指南](docs/functional-regression.md)：发布前自动化回归、手工冒烟、AI 切片验收和验证边界。

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
flutter build linux --release
# 产物位于 build/linux/x64/release/bundle/

# macOS (.app 包)
flutter build macos --release
# 产物位于 build/macos/Build/Products/Release/

# Windows (可执行文件 + DLL)
flutter build windows --release
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
