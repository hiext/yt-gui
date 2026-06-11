# Cloud Deploy: 个人云端 Docker 自托管方案

## 1. 部署目标

个人云端服务用于承接本地上传的分析包、切片文件和可选原片，执行云端切片任务，并提供远程浏览和结果同步能力。

首版目标是自托管，不是公共 SaaS。

## 2. 当前仓库 MVP 部署形态

当前已新增最小自托管服务：

```text
cloud/
  server.mjs
  Dockerfile
  docker-compose.yml
  data/
```

本地启动：

```bash
PAIRING_TOKEN=change-me ACCESS_TOKEN=dev-token node cloud/server.mjs
```

Docker Compose 启动：

```bash
cd cloud
PAIRING_TOKEN=change-me ACCESS_TOKEN=dev-token docker compose up --build
```

健康检查：

```bash
curl http://127.0.0.1:8731/api/health
```

当前 API 已支持：

- `GET /api/health`
- `POST /api/devices/pair`
- `POST /api/media/analysis-package`
- `POST /api/clip-jobs`
- `GET /api/clip-jobs/{jobId}`
- `POST /api/media/{cloudMediaId}/uploads/init`
- `PUT /api/media/{cloudMediaId}/uploads/{uploadId}/chunks/{chunkIndex}`
- `GET /api/media/{cloudMediaId}/uploads/{uploadId}`
- `DELETE /api/media/{cloudMediaId}/uploads/{uploadId}`
- `POST /api/media/{cloudMediaId}/uploads/{uploadId}/complete`
- `POST /api/clip-jobs/{jobId}/run`
- `GET /api/clip-jobs/{jobId}/result-manifest`
- `GET /api/clip-jobs/{jobId}/files/{fileName}`

当前服务端是单进程 MVP：它保存分析包、任务 JSON、分块上传状态、原片对象、切片文件和结果 manifest。本地目录作为对象存储雏形，`POST /api/clip-jobs/{jobId}/run` 会触发单机 Worker；如果已上传原片，Worker 使用 FFmpeg 导出候选切片，否则生成占位切片文件用于验证端到端协议。

## 3. 推荐部署形态

Docker Compose:

```text
cloud/
  docker-compose.yml
  .env.example
  api/
  worker/
  web/
  data/
```

服务组成：

- `api`：HTTP API、鉴权、任务管理、上传管理。
- `worker`：FFmpeg 和 AI 分析执行器。
- `web`：简单 Web UI，可与 API 合并。
- `data`：本地目录对象存储和数据库。

## 4. 目录结构

```text
data/
  db/
  uploads/
  media/
  clips/
  manifests/
  logs/
  tmp/
```

要求：

- `data/` 必须可持久化映射。
- `tmp/` 可清理。
- `logs/` 用于用户排查失败任务。
- `uploads/` 保存分块上传临时文件。

## 5. 环境变量

当前 MVP 代码使用：

```dotenv
PORT=8731
DATA_DIR=/data
PAIRING_TOKEN=change-me
ACCESS_TOKEN=dev-token
EDGE_CLOUD_CLIPS_PORT=8731
FFMPEG_PATH=ffmpeg
```

规划中的完整环境变量：

```dotenv
APP_BASE_URL=https://clips.example.com
APP_DATA_DIR=/data
APP_ADMIN_TOKEN=change-me
APP_PAIRING_SECRET=change-me
APP_JWT_SECRET=change-me
APP_MAX_UPLOAD_BYTES=21474836480
APP_WORKER_CONCURRENCY=1
APP_FFMPEG_PATH=/usr/bin/ffmpeg
APP_FFPROBE_PATH=/usr/bin/ffprobe
APP_ENABLE_ORIGINAL_UPLOAD=true
APP_ENABLE_PUBLIC_SIGNUP=false
```

AI 相关变量后续按 provider 扩展：

```dotenv
AI_PROVIDER=none
AI_OPENAI_API_KEY=
AI_OPENAI_MODEL=
AI_EMBEDDING_MODEL=
```

## 6. 鉴权与配对

### 6.1 管理员 Token

部署者通过 `APP_ADMIN_TOKEN` 初始化服务。该 Token 只用于首次配对和管理操作。

### 6.2 设备配对

流程：

1. 用户在云端生成 Pairing Token。
2. 用户在桌面端输入服务地址和 Pairing Token。
3. 桌面端调用 `POST /api/devices/pair`。
4. 云端返回设备级访问 Token。
5. 后续请求使用设备 Token。

### 6.3 安全要求

- Token 不写日志。
- Pairing Token 有效期有限。
- 可撤销设备。
- 默认不开启公共注册。

## 7. HTTPS 与反代

MVP 不内置证书自动签发，文档提供反代建议：

- Caddy
- Nginx
- Traefik

要求：

- 大文件上传超时时间要调大。
- 请求体大小限制要和 `APP_MAX_UPLOAD_BYTES` 对齐。
- WebSocket 如果用于实时进度，需要反代支持升级。

## 8. 上传策略

默认支持：

- 上传分析包。
- 上传已切片文件。
- 上传用户选择的片段范围信息。

可选支持：

- 上传完整原片。
- 提供远程可访问媒体 URL。

原片上传规则：

- 桌面端必须弹出确认。
- 云端必须记录该任务包含原片。
- 任务完成后是否保留原片由部署配置决定。

## 9. Worker 策略

MVP：

- 单机单 Worker。
- 默认并发 1。
- 本地目录读取输入、写出切片。
- 失败任务保存 stderr 摘要和完整日志路径。
- 当前实现由 `POST /api/clip-jobs/{jobId}/run` 触发执行，适合本地/NAS 小规模自托管和自动化测试。
- `FFMPEG_PATH` 可指向镜像内或宿主挂载的 FFmpeg；未配置时使用 `ffmpeg`。
- 未上传原片时生成占位文件，避免分析包-only 任务阻塞协议验证；正式云端精剪仍要求用户显式上传原片或提供可访问媒体地址。

后续：

- 多 Worker。
- 队列后端抽象。
- GPU 节点。
- S3 兼容对象存储。

## 10. 备份与升级

需要备份：

- `data/db/`
- `data/manifests/`
- `data/clips/`
- `.env`

可以不备份：

- `data/tmp/`
- 未完成的 chunk 临时文件。

升级步骤：

1. 停止服务。
2. 备份数据目录。
3. 拉取新镜像。
4. 启动服务。
5. 检查 migration 日志。

## 11. 运维命令草案

```bash
docker compose up -d
docker compose logs -f api
docker compose logs -f worker
docker compose down
```

## 12. MVP 不做

- 多租户组织权限。
- 公共账号注册。
- 付费、计量和订阅。
- 云端公开分享链接。
- 自动删除本地文件。

## 13. 下一步

- 为 Docker 镜像补充内置 FFmpeg 或明确要求宿主挂载。
- 增加一键冒烟脚本，覆盖健康检查、配对、分析包上传、chunk 上传、任务执行和 manifest 拉取。
- 设计云端 Web UI 或 API 页面，用于远程浏览任务、日志和切片文件。
