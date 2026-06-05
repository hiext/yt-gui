# 第三方工具声明

本项目可以在发布包中内置 `yt-dlp` 和 `ffmpeg`，但这些工具不是本项目原创代码。发布前必须确认版本、来源、校验值和许可证边界。

## 内置策略

- 锁文件：`tools/embedded_tools.lock.json`
- 下载脚本：`dart run tools/fetch_embedded_tools.dart`
- 输出目录：`assets/bin/<platform>/`
- Git 策略：下载后的二进制默认不提交，只提交锁文件和脚本。

应用启动时优先使用设置页自定义路径；未配置时优先使用包内工具；包内工具缺失时再查找系统 `PATH` 和常见安装目录。

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
3. 确认 `assets/bin/<platform>/yt-dlp` 和 `ffmpeg` 可执行。
4. 运行对应平台构建和 GUI 冒烟解析。
5. 在 Release notes 中列出内置工具版本、来源和许可证摘要。

## 免责声明

这些工具仅用于用户在合法授权范围内处理可访问的媒体资源。本项目不提供受版权保护的内容，也不以下载、传播或获取盗版数字数据为目的。
