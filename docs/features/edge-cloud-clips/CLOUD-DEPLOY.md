# Cloud Deploy: 个人云端 Docker 自托管方案

## 1. 部署目标

个人云端服务用于承接本地上传的分析包、切片文件和可选原片，执行云端切片任务，并提供远程浏览和结果同步能力。

首版目标是自托管，不是公共 SaaS。

## 2. 推荐部署形态

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

## 3. 目录结构

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

## 4. 环境变量

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

## 5. 鉴权与配对

### 5.1 管理员 Token

部署者通过 `APP_ADMIN_TOKEN` 初始化服务。该 Token 只用于首次配对和管理操作。

### 5.2 设备配对

流程：

1. 用户在云端生成 Pairing Token。
2. 用户在桌面端输入服务地址和 Pairing Token。
3. 桌面端调用 `POST /api/devices/pair`。
4. 云端返回设备级访问 Token。
5. 后续请求使用设备 Token。

### 5.3 安全要求

- Token 不写日志。
- Pairing Token 有效期有限。
- 可撤销设备。
- 默认不开启公共注册。

## 6. HTTPS 与反代

MVP 不内置证书自动签发，文档提供反代建议：

- Caddy
- Nginx
- Traefik

要求：

- 大文件上传超时时间要调大。
- 请求体大小限制要和 `APP_MAX_UPLOAD_BYTES` 对齐。
- WebSocket 如果用于实时进度，需要反代支持升级。

## 7. 上传策略

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

## 8. Worker 策略

MVP：

- 单机单 Worker。
- 默认并发 1。
- 本地目录读取输入、写出切片。
- 失败任务保存 stderr 摘要和完整日志路径。

后续：

- 多 Worker。
- 队列后端抽象。
- GPU 节点。
- S3 兼容对象存储。

## 9. 备份与升级

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

## 10. 运维命令草案

```bash
docker compose up -d
docker compose logs -f api
docker compose logs -f worker
docker compose down
```

## 11. MVP 不做

- 多租户组织权限。
- 公共账号注册。
- 付费、计量和订阅。
- 云端公开分享链接。
- 自动删除本地文件。

## 12. 下一步

- 确认服务端技术栈。
- 确认 Docker 镜像是否内置 FFmpeg。
- 设计 `.env.example` 和 `docker-compose.yml` 的最小版本。
