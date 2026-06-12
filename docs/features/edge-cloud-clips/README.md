# Edge + 个人云端自动切片

> Status: Edge + personal cloud MVP implementation baseline
> Branch: `codex/edge-cloud-auto-clips`

## 目标

本目录保存新版自动切片功能的结构化需求、研究和实施计划。新版能力不再只做“AI 生成几个片段后自动调用 FFmpeg”，而是升级为基于边缘计算的 C/S 架构：

- 桌面端作为 Edge Client，完成下载后本地分析、本地切片和本地浏览。
- 本地 Worker 承接 FFmpeg、转写、场景检测、向量化等重任务。
- 个人云端 Server 通过 Docker 自托管，支持上传、云端切片、远程浏览和结果同步。
- 用户始终保留本地数据主权，原片上传必须显式授权。

## 文档索引

| 文档 | 用途 |
| --- | --- |
| [PRD.md](./PRD.md) | 产品需求、核心场景、MVP 边界和验收标准 |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Edge Client、本地 Worker、个人云端 Server、对象存储和同步协议 |
| [RESEARCH.md](./RESEARCH.md) | 多轮功能收集、价值研究、方法论和结论台账 |
| [BUSINESS-VALUE.md](./BUSINESS-VALUE.md) | AI 自动切片商业价值、竞品、商业化路径和验证指标 |
| [TASKS.md](./TASKS.md) | 可执行任务拆解，只放实施任务 |
| [DATA-SCHEMA.md](./DATA-SCHEMA.md) | 媒体资产、切片、向量和云端同步数据模型 |
| [CLOUD-DEPLOY.md](./CLOUD-DEPLOY.md) | Docker 自托管部署、环境变量、鉴权、存储和运维 |
| [ROADMAP.md](./ROADMAP.md) | MVP、Beta、Pro 多阶段演进计划 |

## 默认决策

- 部署形态：优先 Docker 自托管，目标环境是 NAS、VPS、家用服务器或个人工作站。
- 上传策略：默认上传分析包和用户选择的片段范围；原片上传为任务级显式确认。
- 云端定位：个人私有云端，不做 SaaS、多租户、公共账号体系和付费系统。
- 本地定位：本地是最终可信数据源，云端是可选扩展节点。
- 实施节奏：先沉淀文档和研究，再做代码改造。

## 当前实现入口

已落地第一版可验证闭环：

- 本地媒体资产模型和 SQLite 表：`MediaAsset`、`MediaAnalysisJob`、`ClipCandidate`、`ClipExportRecord`、`MediaVectorRecord`、`CloudConnectionConfig`、`CloudSyncTask`。
- 下载完成归档：`DownloadController` 调用 `MediaAssetIndexerService`，下载文件存在时创建 `MediaAsset`。
- 本地分析：`LocalAnalysisService` 通过 `ffprobe` 读取元数据，并把候选切片、轻量向量写入新表。
- 本地导出：`LocalClipWorkerService` 通过 FFmpeg 导出 `ClipCandidate`，写入 `ClipExportRecord`。
- 本地进度：`LocalClipWorkerService` 解析 FFmpeg `stderr time=...`，持续写入导出进度。
- 旧数据兼容：`MediaAssetRepository` 可把旧 `ClipSegment`、`ClipRecord` 只读映射成新候选和导出记录。
- 旧入口兼容：`AutoClipService` 保持旧自动切片入口可用，并把结果镜像到新媒体库导出记录。
- 本地媒体库 UI：Clips 页展示媒体资产、候选切片、导出记录、状态筛选、搜索和本地打开入口；切片结果以预览画廊卡片呈现，包含 FFmpeg 缓存预览图、时间范围、摘要、切片原因、状态和打开片段入口。
- 个人云端设置：Settings 页支持服务地址、设备名、Pairing Token、访问 Token、同步开关和上传策略。
- 个人云端 client：`CloudClipClient` 支持健康检查、设备配对、分析包上传、原片分块上传/查询/取消、创建任务、查询任务和拉取结果 manifest。
- 自托管服务：`cloud/server.mjs`、`cloud/Dockerfile`、`cloud/docker-compose.yml` 支持本地目录对象存储、分块上传、上传取消/续传状态、Worker 执行、结果 manifest 和切片文件下载。

## 验证命令

```bash
flutter test test/core/models/media_library_models_test.dart \
  test/core/services/media_asset_repository_test.dart \
  test/core/services/media_asset_indexer_service_test.dart \
  test/core/services/local_analysis_service_test.dart \
  test/core/services/local_clip_worker_service_test.dart \
  test/core/services/cloud_clip_client_test.dart \
  test/features/clips/clip_library_page_test.dart \
  test/features/settings/settings_page_test.dart \
  test/core/controllers/download_controller_test.dart

node --test test/cloud/server.test.mjs
```

## 后续研究节奏

1. 现有功能盘点：确认当前 AI 切片不可用的根因、可复用点和迁移点。
2. 用户价值研究：明确本地切片、云端切片、远程浏览、跨设备同步和个人素材库的价值。
3. 功能地图：按下载后信息提取、本地分析、本地切片、本地浏览、上传云端、云端重切、结果同步拆解。
4. 架构可行性：研究 Docker、断点续传、FFmpeg Worker、对象存储、队列和鉴权。
5. 实施切片：把能力切成 MVP、Beta、Pro，先完成最小闭环。

## 当前不做

- 不实现公共 SaaS 服务、多租户、付费系统或公共账号体系。
- 不默认上传原片、Cookie、API Key 或个人账号数据。
- 不实现云端 Web UI 和浏览器播放器。
- 不实现真实 embedding 模型，当前向量仍是本地轻量 hash baseline。
