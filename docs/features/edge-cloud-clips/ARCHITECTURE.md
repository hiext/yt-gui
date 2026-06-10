# Architecture: Edge + 个人云端自动切片

## 1. 架构目标

新版自动切片采用 C/S 架构，但本地不是轻客户端。本地桌面端承担边缘计算职责，云端是个人可选扩展节点。

核心原则：

- 本地优先：本地下载、本地切片、本地浏览必须独立可用。
- 云端增强：云端提供远程切片、长任务托管、跨设备同步和 Web 浏览。
- 数据可回流：云端结果必须能同步回本地，成为本地媒体库的一部分。
- 私有部署：首版只支持个人自托管，不做公共 SaaS。

## 2. 组件

### 2.1 Desktop Edge Client

Flutter 桌面应用，负责：

- 下载任务管理。
- 媒体资产创建。
- 本地分析和切片任务编排。
- 本地媒体库浏览。
- 云端配置、配对、上传和结果同步。
- 用户确认原片上传、删除、重算等敏感动作。

### 2.2 Local Edge Worker

本地执行层，负责：

- `ffprobe` 元数据提取。
- FFmpeg 切片、缩略图、关键帧抽样。
- 本地 sidecar 分析。
- 进度、取消、重试和日志。
- 资源限制，例如并发数、CPU 占用和临时目录。

MVP 可以先以 Dart service + process runner 形式实现，后续再拆成独立后台进程。

### 2.3 Personal Cloud Server

个人云端 API，Docker 自托管，负责：

- 设备配对和鉴权。
- 媒体资产 manifest 接收。
- 大文件分块上传。
- 云端切片任务创建、查询和取消。
- 结果下载、日志查看和同步。
- Web UI 基础浏览。

### 2.4 Cloud Worker

云端执行层，负责：

- 从队列领取切片任务。
- 读取对象存储中的原片、已切片文件或分析包。
- 执行 FFmpeg 切片、云端分析和导出。
- 写入结果 manifest、切片文件和日志。

### 2.5 Object Storage

MVP 先使用本机目录映射：

```text
data/
  media/
  uploads/
  clips/
  manifests/
  logs/
  tmp/
```

后续可扩展到 S3 兼容对象存储。

## 3. 数据流

### 3.1 本地切片

```text
Download completed
  -> MediaAsset created
  -> Local analysis manifest generated
  -> Clip candidates generated
  -> User reviews or auto-runs local export
  -> FFmpeg creates clip files
  -> ClipExportRecord saved
  -> Clips library updates
```

### 3.2 上传分析包到云端

```text
MediaAsset + analysis manifest
  -> CloudSyncTask created
  -> POST /api/media
  -> POST /api/clip-jobs
  -> Cloud worker evaluates task
  -> Results manifest generated
  -> Desktop pulls result
```

### 3.3 上传原片到云端切片

```text
User confirms original upload
  -> Chunked upload starts
  -> Server validates hash
  -> Clip job queued
  -> Worker runs FFmpeg / AI analysis
  -> Clip files and manifest saved
  -> Desktop imports cloud result
```

## 4. 同步协议

### 4.1 基本要求

- 每个同步任务有幂等键。
- 大文件上传支持断点续传。
- 服务端保存每个 chunk 的状态。
- 客户端可取消或重试。
- 云端结果不会静默覆盖本地用户调整。

### 4.2 冲突规则

- 本地手动调整优先级高于云端自动结果。
- 云端生成的新切片作为新版本导入。
- 删除操作不自动跨端传播，MVP 只做显式删除。
- 同一媒体通过 `sourceUrl + fileSha256 + durationMs` 识别重复。

## 5. 云端 API 草案

```text
POST   /api/devices/pair
GET    /api/health
POST   /api/media
GET    /api/media
GET    /api/media/{mediaId}
POST   /api/media/{mediaId}/uploads/init
PUT    /api/media/{mediaId}/uploads/{uploadId}/chunks/{index}
POST   /api/media/{mediaId}/uploads/{uploadId}/complete
POST   /api/clip-jobs
GET    /api/clip-jobs/{jobId}
POST   /api/clip-jobs/{jobId}/cancel
GET    /api/media/{mediaId}/results
POST   /api/sync/pull
```

## 6. 本地服务分层

```text
Controller
  -> MediaLibraryController
  -> CloudSyncController

Services
  -> MediaAssetService
  -> LocalAnalysisService
  -> LocalClipWorkerService
  -> CloudClipClient
  -> CloudSyncService

Repositories
  -> MediaAssetRepository
  -> ClipCandidateRepository
  -> ClipExportRepository
  -> MediaVectorRepository
  -> CloudSyncRepository
```

## 7. 错误处理

| 场景 | 行为 |
| --- | --- |
| 本地 FFmpeg 不可用 | 本地切片失败，分析结果仍可浏览 |
| 云端不可达 | 同步任务保持 pending，可手动重试 |
| 上传中断 | 保留已上传 chunk，恢复后续传 |
| 云端切片失败 | 回传日志和错误，保留本地任务 |
| 原片未授权上传 | 云端只能处理分析包或已切片文件 |
| 云端版本不兼容 | 客户端提示升级或降级到本地处理 |

## 8. 下一步

- 确认本地数据库表和云端 API schema。
- 设计分块上传状态机。
- 确认云端 Worker MVP 使用 SQLite 队列还是文件队列。
