# 第三方工具声明

本项目可以在发布包中内置 `yt-dlp` 和 `ffmpeg`，但这些工具不是本项目原创代码。发布前必须确认版本、来源、校验值和许可证边界。

## 内置策略

- 锁文件：`tools/embedded_tools.lock.json`
- 下载脚本：`dart run tools/fetch_embedded_tools.dart`
- 输出目录：`assets/bin/<platform>/`
- Git 策略：下载后的二进制默认不提交，只提交锁文件和脚本。
- 构建策略：每次正式构建前运行 `tools/fetch_embedded_tools.dart --platform=<platform>`，将锁定版本刷新到 `assets/bin/<platform>/`。
- 镜像策略：每个 artifact 可配置 `mirrors` 数组；主下载地址失败或校验不通过时，脚本按顺序尝试镜像，并仍以同一 SHA256 作为最终准入条件。

应用启动和执行切片/下载时必须使用同一条工具解析规则：设置页已验证正确的路径最高优先级；未配置时查找系统 `PATH` 和常见安装目录；最后使用包内工具。自定义路径不能只判断文件存在，还必须确认它指向对应工具，至少阻止 `yt-dlp`/`ffmpeg` 填反，并要求用户可用 `yt-dlp --version` / `ffmpeg --version` 验证。三层都不可用时必须给出明确错误，提示用户设置路径、安装系统工具或刷新内置包，不能静默报“找不到工具”。

## yt-dlp

- 来源：`yt-dlp/yt-dlp` GitHub release
- 当前锁定版本：`2026.03.17`
- 许可证：`Unlicense`，release binary 还包含第三方依赖声明。
- 发布要求：保留 release 链接、SHA256 校验值和第三方依赖声明入口。

## FFmpeg

- Linux / Windows 来源：`BtbN/FFmpeg-Builds` GitHub release
- 当前锁定版本：`n8.1 latest build 2026-06-04`
- 许可证策略：默认仅使用 `LGPL` 构建。
- macOS：暂不默认内置。若要内置，需先补充可信供应源、签名/公证状态、SHA256 和许可证说明。

禁止在未评审的情况下发布 `GPL` 或 `nonfree` FFmpeg 构建。若选择 GPL 构建，发布说明和源码义务需要另行处理。

## 发布检查

1. 运行 `dart run tools/fetch_embedded_tools.dart --dry-run`，确认计划下载项。
2. 运行目标平台下载命令，例如 `dart run tools/fetch_embedded_tools.dart --platform=linux,windows`。
3. 确认 `assets/bin/<platform>/yt-dlp` 和 `ffmpeg` 可执行；macOS 若继续使用 manual FFmpeg，必须在 release gate 中写明系统/Homebrew/自定义路径要求。
4. 运行对应平台构建和 GUI 冒烟解析，至少覆盖下载解析和本地切片。
5. 在 Release notes 中列出内置工具版本、来源、镜像策略和许可证摘要。

## 免责声明

这些工具仅用于用户在合法授权范围内处理可访问的媒体资源。本项目不提供受版权保护的内容，也不以下载、传播或获取盗版数字数据为目的。
