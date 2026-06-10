# Roadmap: 多轮功能演进计划

## 1. 原则

- 先文档和研究，后代码实现。
- 先本地闭环，后云端闭环。
- 先个人自托管，后增强部署体验。
- 先显式上传，后自动同步。
- 先可解释切片，后更复杂的 AI 推荐。

## 2. Round 1: 文档与研究基线

目标：

- 保存结构化文档。
- 明确 Edge + 个人云端 C/S 架构。
- 完成现有功能盘点。
- 完成 MVP 边界。

交付：

- `README.md`
- `PRD.md`
- `ARCHITECTURE.md`
- `RESEARCH.md`
- `TASKS.md`
- `DATA-SCHEMA.md`
- `CLOUD-DEPLOY.md`
- `ROADMAP.md`

## 3. Round 2: 本地媒体资产 MVP

目标：

- 下载完成后生成媒体资产。
- 本地保存媒体 manifest。
- 旧切片数据可展示。

交付：

- 本地模型和 repository。
- SQLite migration。
- 本地资产基础测试。

验收：

- 完成下载后能看到媒体资产记录。
- 应用重启后记录仍存在。

## 4. Round 3: 本地切片闭环

目标：

- 本地候选切片。
- 本地 FFmpeg 导出。
- 本地切片库浏览。

交付：

- Local Edge Worker。
- ClipExportRecord。
- Clips 页面基础升级。

验收：

- 用户不配置云端也能完成分析、切片、浏览。

## 5. Round 4: 个人云端连接 MVP

目标：

- 设置页配置个人云端。
- 设备配对。
- 上传分析包。
- 创建云端任务。
- 拉取任务状态。

交付：

- CloudConnectionConfig。
- CloudClipClient。
- mock server 测试。

验收：

- 本地可以连接 mock 或真实开发服务。
- 云端任务状态可显示在桌面端。

## 6. Round 5: Docker 云端 MVP

目标：

- Docker Compose 启动个人云端。
- API 服务和 Worker 跑通。
- 支持分析包和已切片文件上传。
- 提供任务列表和日志。

交付：

- `cloud/` 或 `server/` 子项目。
- Dockerfile。
- `docker-compose.yml`。
- `.env.example`。
- 基础 Web UI 或 API 页面。

验收：

- 用户可在 VPS/NAS 上启动服务。
- 桌面端可提交云端任务。

## 7. Round 6: 原片可选上传与云端重切

目标：

- 分块上传原片。
- 断点续传。
- 云端 FFmpeg 重切。
- 结果 manifest 和切片文件回传。

交付：

- chunk upload API。
- 上传状态机。
- cloud worker FFmpeg。
- 本地结果导入。

验收：

- 用户确认后可上传原片。
- 云端切片结果能回到本地媒体库。

## 8. Round 7: 向量检索和素材库增强

目标：

- 结构化搜索 + 语义检索。
- 媒体、字幕窗口、候选切片向量化。
- 跨媒体搜索。

交付：

- MediaVectorRecord。
- 本地向量存储。
- 搜索 UI 增强。

验收：

- 用户可以用自然语言找到相关片段。

## 9. Round 8: Beta 稳定化

目标：

- 完善失败恢复。
- 完善隐私提示。
- 完善部署文档。
- 补齐回归测试。

交付：

- 功能回归指南更新。
- Docker 冒烟脚本。
- UI 和服务测试。

验收：

- 本地和云端 MVP 可作为 Beta 使用。

## 10. 暂不进入路线图

- 公共 SaaS。
- 多租户组织。
- 付费系统。
- 移动端。
- 公共分享站点。
