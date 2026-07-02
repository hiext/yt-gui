# Edge + 个人云端自动切片测试覆盖

## 目标

本文件记录自动切片相关测试的适用场景、覆盖边界和推荐回归命令。它用于后续继续改 Clips 页、本地 Worker、个人云端或数据模型时快速判断应该跑哪些测试。

## 适用范围

- 下载完成后的媒体资产归档和媒体库索引。
- 本地 ffprobe 分析、候选片段生成、轻量向量记录。
- 本地 FFmpeg 切片导出、失败记录、进度解析。
- `yt-dlp` / `ffmpeg` 工具解析优先级：设置页正确路径 > 系统工具 > 内置资源包。
- Clips 页媒体资产浏览、片段画廊、预览、重新生成、删除、清空和整理筛选。
- 个人云端 client、Docker 自托管服务、分块上传、云端任务和 result manifest。

## 已覆盖用例

### 数据层

- `test/core/models/media_library_models_test.dart`
  - `MediaAsset`、`ClipCandidate`、`CloudConnectionConfig`、`CloudSyncTask` 序列化。
- `test/core/services/media_asset_repository_test.dart`
  - 媒体资产、分析任务、候选切片、导出记录、向量记录、云端配置和同步任务保存读取。
  - 旧 `ClipSegment` 到 `ClipCandidate` 的只读兼容。
  - 旧 `ClipRecord` 到 `ClipExportRecord` 的只读兼容。
  - 删除候选切片时同步删除候选关联的导出记录和向量记录。
  - 独立删除导出记录时保留候选切片。
  - 清空媒体资产生成结果时保留媒体资产，删除分析任务、候选、导出、向量和同步任务。

### 本地 Worker

- `test/core/services/local_analysis_service_test.dart`
  - ffprobe 元数据提取、候选切片和向量记录写入。
  - ffprobe 失败时写入失败分析状态。
- `test/core/services/local_clip_worker_service_test.dart`
  - FFmpeg 导出候选切片并保存 `ClipExportRecord`。
  - FFmpeg 失败时保存失败导出记录。
  - 解析 FFmpeg `stderr time=...` 并保存中间进度。
- `test/core/services/embedded_tool_resolver_test.dart`
  - 自定义路径最高优先级。
  - 自定义路径必须指向对应工具，阻止 `yt-dlp` / `ffmpeg` 填反。
  - 未配置时优先使用系统 `PATH` 和 Homebrew 等常见目录。
  - 系统工具不可用时最后使用内置资源路径。
- `test/core/services/ffmpeg_clip_executor_test.dart`
  - 系统 FFmpeg 存在时不先加载内置资源。
- `test/core/services/process_yt_dlp_executor_test.dart`
  - 系统 yt-dlp 存在时不先加载内置资源。
- `test/core/services/clip_preview_service_test.dart`
  - 完成导出后从切片开头生成缓存预览图。

### Clips 页面

- `test/features/clips/clip_library_page_test.dart`
  - 空媒体库状态。
  - 媒体资产、候选切片和导出记录展示。
  - 片段画廊卡片展示预览区域、时间范围、标题、摘要、原因、状态和打开片段入口。
  - 搜索候选标题、摘要、标签、关键词和导出状态。
  - 打开原媒体和输出目录。
  - 注入式预览、重新生成和删除回调。
  - 默认重新生成走 `LocalClipWorkerService`。
  - 默认预览打开已导出切片文件。
  - 旧 `ClipSegment` 结果卡片在没有媒体资产记录时仍可打开导出切片或原视频文件。
  - 旧 `ClipSegment` 结果没有导出产物时，可通过 `AutoClipService.cutSingle` 即时生成切片并打开。
  - 旧 `ClipSegment` 结果按来源任务分组展示，并支持 `Needs export` / `Exported` 状态筛选。
  - 旧 `ClipSegment` 结果支持删除，删除后从管理列表和搜索索引中移除。
  - `Cut clip` 失败时展示错误原因，避免用户点击后无反馈。
  - 默认删除和清空通过 repository 更新数据并刷新页面。
  - `High score` 和 `Needs review` 质量筛选。

### 个人云端

- `test/core/services/cloud_clip_client_test.dart`
  - 健康检查、设备配对、分析包上传、云端任务创建、分块上传、取消和 result manifest 拉取。
- `node --test test/cloud/server.test.mjs`
  - Docker 自托管服务 API、鉴权、分块上传、SHA256 校验、Worker 执行、result manifest 和切片文件下载。

## 推荐回归命令

### 修改 Clips 页面或切片管理动作

```bash
flutter test test/features/clips/clip_library_page_test.dart -r expanded
flutter test test/core/services/media_asset_repository_test.dart -r expanded
```

### 修改本地分析、切片、预览

```bash
flutter test test/core/services/embedded_tool_resolver_test.dart -r expanded
flutter test test/core/services/process_yt_dlp_executor_test.dart \
  test/core/services/ffmpeg_clip_executor_test.dart -r expanded
flutter test test/core/services/local_analysis_service_test.dart \
  test/core/services/local_clip_worker_service_test.dart \
  test/core/services/clip_preview_service_test.dart -r expanded
```

### 修改个人云端 client 或服务端

```bash
flutter test test/core/services/cloud_clip_client_test.dart -r expanded
node --test test/cloud/server.test.mjs
```

### 发布前本地回归

```bash
flutter analyze --no-fatal-infos
flutter test
git diff --check
```

## 尚未覆盖

- 真实桌面端视频文件的手工预览和播放体验。
- 真实 embedding 模型或外部转写/视觉模型集成。
- 云端 Web UI 和浏览器播放器。
- 多设备长期同步冲突解决。
