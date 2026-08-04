# 换声功能上线材料

> 配套设计文档：[voice-swap-design.md](voice-swap-design.md)。本文件记录上线配置、模型校验回填机制与分阶段验收结果，随功能分支 `codex/voice-swap` 提交，发布前按此核对。

## 1. 功能与边界（已确认）

- 本期：离线换声（离线全流程），实时变声（RVC）仅进后续规划，不实现。
- 人声/伴奏分离一期必需：背景音乐保留，人声被替换。
- 目标声音来源：一期内置预设备色（8 款 Kokoro 中文音色）；录制/上传克隆（v1.1）预留。
- 平台优先级：macOS 优化，Linux / Windows 顺带支持。
- 全部处理在本机完成；模型首次使用时下载（约 325MB），之后离线可用。

## 2. 设置项（properties 示例）

换声设置独立持久化在 `DownloadSettings.voiceSwap`，JSON 键前缀 `voice_swap.`。示例与默认值：

```jsonc
{
  "voice_swap.model_dir": "/Users/you/Library/Application Support/hiext_yt_gui",
  // 可选。默认：平台应用数据目录（macOS 为上述路径）。目录下包含
  // downloads/、.checksums/、models/<id>/；留空用默认。
  "voice_swap.preset_voice": "kokoro-zf-xiaobei",
  // 可选。默认：kokoro-zf-xiaobei（Kokoro 中文女声）。可选 8 个内置 id：
  // kokoro-zf-xiaobei / -xiaoni / -xiaoxiao / -xiaoyi（女）
  // kokoro-zm-yunjian / -yunxi / -yunxia / -yunyang（男）
  "voice_swap.auto_download_models": true,
  // 可选。默认：true。关闭后模型缺失时直接报错并提示手动放置/开启下载。
  "voice_swap.separation_engine": "uvr",
  // 可选。默认：uvr。内部模型 id，不暴露 UI；spleeter 为备选。
  "voice_swap.separation_bin_path": "",
  // 可选。默认：按「设置路径 > PATH/常见目录 > 内置 assets」解析。
  // 与 ffmpegPath 同语义，自定义路径必须验证为对应 CLI。
}
```

## 3. 模型下载与 sha256 回填机制

- 模型目录布局：`downloads/<id>`（原始文件）、`.checksums/<id>.sha256`（sidecar 校验值）、`models/<id>/`（普通模型单文件 / 压缩包解压内容）。
- `VoiceSwapModelCatalog.models` 中 `sha256` 为可选项：有值则强校验；为空时由 `VoiceSwapModelManager` 首次下载后计算并写入 sidecar，后续启动按 sidecar 校验，文件被篡改即判定不可用并重新下载。
- 当前已锁定：macOS 分离 CLI 包 sha256（`sherpa-onnx-sep-macos`，`02b9b0cf…`）与模型 `uvr`（`1edd6f68…`，已实际下载验证）。SenseVoice / VAD / Kokoro 未预锁，首次下载后自动回填 sidecar。
- 模型许可（发布需知）：UVR 保留署名；SenseVoice 保留模型名；Kokoro Apache-2.0；Matcha-zh(baker) 仅限非商用（默认不选）。详见 `docs/third-party-tools.md`。

## 4. 分阶段验收记录

| 阶段 | 结果 | 说明 |
|---|---|---|
| 1. 分离 CLI PoC | 通过 | 内置 `sherpa-onnx-offline-source-separation`（macOS）对 10s 双音调 wav 正确产出 vocals/accompaniment，RTF≈1.13；arm64 原生在沙箱内被 SIGKILL 属环境限制，`arch -x86_64`（Rosetta）可运行 |
| 2. 单元测试 | 通过 | 新增 5 个测试文件共 36 个用例：模型管理（下载/校验/解压/取消）、分离 CLI 解析、ffmpeg 命令构造、控制器状态机、流水线编排 |
| 3. 全量回归 | 通过（1 个既有失败除外） | `flutter test` 全量通过，唯一失败为 `license_client_test.dart` 使用本机不存在的 `/bin/false`（macOS 为 `/usr/bin/false`），与本功能无关，属既有环境问题 |
| 4. 静态检查 | 通过 | `flutter analyze --no-fatal-infos` 无 error；仅剩 1 个既有 info（`tools/fetch_embedded_tools.dart` 字符串拼接），非本功能引入 |
| 5. 真实视频端到端 | 通过 | 真实 15s 视频（中文人声+背景音乐）：提取音轨 → UVR 分离 → SenseVoice 识别 5 句 → Kokoro 逐句合成 → 混音 → 封装，69s 完成，输出保留 h264 画面 + aac 44.1kHz 双声道音频，时长与源一致（14.98s） |
| 6. 冒烟驱动缺陷修复 | 完成 | ①分离 CLI arm64 原生启动失败（universal2 官方切片在 macOS 26 报 Code Signature Invalid 被 dyld SIGKILL）：解压后 ad-hoc 重签名，arm64 原生跑通；②`modelDir` 默认值多带 `/models` 导致首启下载到错误层级，已修正；③Kokoro 模型文件 `model.int8.onnx` 与 `dict/` 中文词典未匹配引擎，已补候选名与 `dictDir`；④ffmpeg 进程 stderr 管道未及时消费导致死锁，改为显式 `listen` 消费；⑤冒烟用例误用 `testWidgets`（FakeAsync 下真实进程 I/O 不完成），改用 `test()` 并显式初始化 binding |

## 5. 发布前检查清单

- [x] `dart run tools/fetch_embedded_tools.dart --platform=macos,linux,windows` 刷新内置工具（含 sherpa-onnx 分离 CLI；本轮已物化三平台）
- [ ] `flutter analyze --no-fatal-infos` 无 error
- [x] `flutter test` 全量通过（415 通过、2 跳过；唯一失败为既有 `license_client_test` 环境问题）
- [ ] 三平台构建：`flutter build macos` / `linux` / `windows`
- [ ] macOS 签名/公证产物确认不含模型目录（模型在用户数据目录）
- [ ] 首次使用网络提示：发布说明写明「换声功能首次使用需联网下载约 325MB 模型」

> 注：`assets/bin/<platform>/sherpa-sep/` 二进制不提交仓库（与 yt-dlp/ffmpeg 同策略），发布构建前必须重新执行上方 fetch 命令物化。

## 6. 手工验收步骤（macOS）

1. `flutter run -d macos` 启动，左侧导航出现「换声」入口。
2. 首次进入换声页或点击「开始换声」：自动下载模型（进度可见），下载完成后可离线重复使用。
3. 选择一个含人声+背景音乐的视频：输出视频应保留伴奏，人声变为所选预设备色。
4. 设置页「换声设置」：修改默认音色、模型目录、关闭自动下载后，分别验证生效与错误提示。
5. 处理过程中点击「取消」：任务进入已取消状态，不产生半成品输出文件。

真实端到端冒烟（自动化，需已下载模型与内置 CLI）：

```bash
VS_SMOKE_MODEL_DIR=/private/tmp/vs-smoke \
VS_SMOKE_VIDEO=/path/to/input.mp4 \
VS_SMOKE_OUT=/path/to/out \
VS_SMOKE_FFMPEG=$(which ffmpeg) \
flutter test test/features/voice_swap/real_voice_swap_smoke_test.dart -r expanded
```

模型目录结构要求：`models/uvr/UVR_MDXNET_1_9703`、`models/vad/silero_vad`、`models/asr-sensevoice/sherpa-onnx-*/*`、`models/tts-kokoro/*`；缺环境变量时用例自动跳过。

## 7. 已知边界与风险

- 首次使用需要网络下载模型；模型体积约 325MB，下载中断可重试（断点续传未实现，重试会重新下载）。
- ASR 依赖清晰人声；无歌词/纯音乐视频会提示「未识别到人声」。
- 混音按原句时间槽放置，过长/过短句会做截断与淡入淡出。
- macOS 内置分离 CLI 为 universal2 官方切片，arm64 在 macOS 26 上需 ad-hoc 重签名才能原生运行（执行器解压时自动处理，仅记日志不阻断；Rosetta 不受影响）。
- 实时变声（RVC）、录制/上传克隆（ZipVoice）已预留模型与目录结构，本期不暴露 UI。
