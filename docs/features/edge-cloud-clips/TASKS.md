# Tasks: Edge + 个人云端自动切片

> 本文件只记录可执行任务，不放研究结论。研究结论见 [RESEARCH.md](./RESEARCH.md)。

## Phase 0: 文档基线

- [x] 新建分支 `codex/edge-cloud-auto-clips`。
- [x] 新增 `docs/features/edge-cloud-clips/`。
- [x] 保存 README、PRD、ARCHITECTURE、RESEARCH、TASKS、DATA-SCHEMA、CLOUD-DEPLOY、ROADMAP。
- [ ] 基于后续讨论继续更新研究文档。

## Phase 1: 现有功能盘点

- [ ] 梳理 `PostProcessController` 中下载完成后的后处理入口。
- [ ] 梳理 `AiClipAnalyzerExecutor` 的内置、sidecar、cloud endpoint 三种路径。
- [ ] 梳理 `AutoClipService` 与 FFmpeg 切片执行链路。
- [ ] 梳理 `ClipSegment`、`ClipRecord`、`clip_segments`、`clip_records` 的迁移策略。
- [ ] 形成 `RESEARCH.md` 的现有功能盘点补充记录。

## Phase 2: 本地媒体资产数据层

- [ ] 新增 `MediaAsset`、`MediaAnalysisJob`、`ClipCandidate`、`ClipExportRecord`、`MediaVectorRecord`、`CloudSyncTask` 模型。
- [ ] 新增 SQLite migration，保存媒体资产、候选切片、导出记录、向量记录和同步任务。
- [ ] 新增对应 repository。
- [ ] 增加旧 `ClipSegment` 和 `ClipRecord` 的只读兼容入口。
- [ ] 添加模型序列化和 migration 单元测试。

## Phase 3: 本地 Edge Worker

- [ ] 抽象 `LocalClipWorkerService`。
- [ ] 抽象 `LocalAnalysisService`。
- [ ] 接入 ffprobe 元数据提取。
- [ ] 接入 FFmpeg 切片、进度、取消和失败日志。
- [ ] 将旧 `AutoClipService` 迁移为兼容调用层或废弃入口。
- [ ] 添加本地切片 focused tests。

## Phase 4: 本地媒体库 UI

- [ ] 将 Clips 页升级为媒体资产库。
- [ ] 增加媒体列表、候选切片列表、导出记录和状态筛选。
- [ ] 支持搜索标题、标签、转写、摘要和切片原因。
- [ ] 支持打开本地文件和本地输出目录。
- [ ] 添加 Widget 测试。

## Phase 5: 个人云端配置与同步客户端

- [ ] 新增 `CloudConnectionConfig`。
- [ ] 设置页新增个人云端服务地址、设备名、Pairing Token、访问 Token、同步开关。
- [ ] 新增 `CloudClipClient`。
- [ ] 实现 `/api/health`、设备配对、上传分析包、创建云端任务、查询任务状态的 client。
- [ ] 添加 mock server 测试。

## Phase 6: Docker 自托管云端

- [ ] 新增 `cloud/` 或 `server/` 子项目。
- [ ] 新增 Dockerfile。
- [ ] 新增 `docker-compose.yml`。
- [ ] 实现 API 服务。
- [ ] 实现 Worker。
- [ ] 实现本地目录对象存储。
- [ ] 实现健康检查和日志。
- [ ] 添加服务端 API 测试。

## Phase 7: 大文件上传与云端切片

- [ ] 实现分块上传初始化。
- [ ] 实现 chunk 上传。
- [ ] 实现上传完成校验。
- [ ] 实现上传取消和续传。
- [ ] 实现云端 FFmpeg 切片。
- [ ] 实现云端结果 manifest 和切片文件回传。
- [ ] 添加断点续传和云端切片集成测试。

## Phase 8: 发布前验证

- [ ] 更新 `README.md` 的功能说明和云端部署入口。
- [ ] 更新 `docs/functional-regression.md`。
- [ ] 运行 `flutter analyze --no-fatal-infos`。
- [ ] 运行相关 focused tests。
- [ ] 运行 `flutter test`。
- [ ] 验证 Docker Compose 云端启动冒烟。
