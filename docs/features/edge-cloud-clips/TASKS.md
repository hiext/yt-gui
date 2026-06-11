# Tasks: Edge + 个人云端自动切片

> 本文件只记录可执行任务，不放研究结论。研究结论见 [RESEARCH.md](./RESEARCH.md)。

## Phase 0: 文档基线

- [x] 新建分支 `codex/edge-cloud-auto-clips`。
- [x] 新增 `docs/features/edge-cloud-clips/`。
- [x] 保存 README、PRD、ARCHITECTURE、RESEARCH、TASKS、DATA-SCHEMA、CLOUD-DEPLOY、ROADMAP。
- [x] 基于后续讨论继续更新研究文档。

## Phase 1: 现有功能盘点

- [x] 梳理 `PostProcessController` 中下载完成后的后处理入口。
- [x] 梳理 `AiClipAnalyzerExecutor` 的内置、sidecar、cloud endpoint 三种路径。
- [x] 梳理 `AutoClipService` 与 FFmpeg 切片执行链路。
- [x] 梳理 `ClipSegment`、`ClipRecord`、`clip_segments`、`clip_records` 的迁移策略。
- [x] 形成 `RESEARCH.md` 的现有功能盘点补充记录。

## Phase 2: 本地媒体资产数据层

- [x] 新增 `MediaAsset`、`MediaAnalysisJob`、`ClipCandidate`、`ClipExportRecord`、`MediaVectorRecord`、`CloudSyncTask` 模型。
- [x] 新增 SQLite migration，保存媒体资产、候选切片、导出记录、向量记录和同步任务。
- [x] 新增对应 repository。
- [x] 增加旧 `ClipSegment` 和 `ClipRecord` 的只读兼容入口。
- [x] 添加模型序列化和 migration 单元测试。
- [x] 下载完成后通过 `MediaAssetIndexerService` 自动创建本地媒体资产。

## Phase 3: 本地 Edge Worker

- [x] 抽象 `LocalClipWorkerService`。
- [x] 抽象 `LocalAnalysisService`。
- [x] 接入 ffprobe 元数据提取。
- [x] 接入 FFmpeg 切片、取消和失败记录。
- [x] 接入 FFmpeg 实时进度解析。
- [x] 将旧 `AutoClipService` 迁移为兼容调用层或废弃入口。
- [x] 添加本地切片 focused tests。

## Phase 4: 本地媒体库 UI

- [x] 将 Clips 页升级为媒体资产库。
- [x] 增加媒体列表、候选切片列表、导出记录和状态筛选。
- [x] 支持搜索标题、标签、转写、摘要和切片原因。
- [x] 支持打开本地文件和本地输出目录。
- [x] 添加 Widget 测试。

## Phase 5: 个人云端配置与同步客户端

- [x] 新增 `CloudConnectionConfig`。
- [x] 设置页新增个人云端服务地址、设备名、Pairing Token、访问 Token、同步开关。
- [x] 新增 `CloudClipClient`。
- [x] 实现 `/api/health`、设备配对、上传分析包、创建云端任务、查询任务状态的 client。
- [x] 添加 mock server 测试。

## Phase 6: Docker 自托管云端

- [x] 新增 `cloud/` 或 `server/` 子项目。
- [x] 新增 Dockerfile。
- [x] 新增 `docker-compose.yml`。
- [x] 实现 API 服务。
- [x] 实现 Worker。
- [x] 实现本地目录对象存储。
- [x] 实现健康检查。
- [x] 实现结构化日志。
- [x] 添加服务端 API 测试。

## Phase 7: 大文件上传与云端切片

- [x] 实现分块上传初始化。
- [x] 实现 chunk 上传。
- [x] 实现上传完成校验。
- [x] 实现上传取消和续传。
- [x] 实现云端 FFmpeg 切片。
- [x] 实现云端结果 manifest 和切片文件回传。
- [x] 添加断点续传和云端切片集成测试。

## Phase 8: 发布前验证

- [x] 更新 `README.md` 的功能说明和云端部署入口。
- [x] 更新 `docs/functional-regression.md`。
- [x] 运行 `flutter analyze --no-fatal-infos`。
- [x] 运行相关 focused tests。
- [x] 运行 `flutter test`。
- [ ] 验证 Docker Compose 云端启动冒烟。

备注：Docker Compose 已确认本机 CLI 可用，但当前 Docker daemon 未启动，`docker compose up -d --build` 无法连接 `/Users/harmay/.docker/run/docker.sock`，因此暂不勾选启动冒烟。
