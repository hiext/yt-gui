# 一键换声（Voice Swap）功能设计

> 分支：`codex/voice-swap`
> 状态：设计已确认（2026-08-04），进入实施
> 关联：`docs/third-party-tools.md`（第三方工具清单需同步更新）

## 1. 功能说明

### 1.1 需求

在 yt-gui 桌面端（macOS 优先，Linux/Windows 顺带支持）集成**全程离线**的语音识别与语音合成链路，提供「一键换声」：用户选择一个视频，应用将其中的人声替换为目标音色，同时**完整保留背景音乐/伴奏**。

### 1.2 已确认边界

1. **离线换声**本期实现；实时变声（RVC 等）只进未来规划，不在本期。
2. **人声/伴奏分离第一期就必须做**（背景音乐要保留）。
3. **目标声音来源**：
   - 内置预设音色（开箱即用，MVP）；
   - 录制 / 上传参考音频 + 零样本声音克隆（二期 v1.1）。
4. **平台优先级**：macOS 优化，Linux/Windows 顺带支持（同一套代码，模型/工具按平台分发）。

### 1.3 用户流程（MVP）

```
换声页面
  ├─ 选择视频文件（file_picker，支持 mp4/mkv/webm 等 ffmpeg 可解容器）
  ├─ 选择目标音色（内置预设下拉）
  ├─ 点击「开始换声」
  ├─ 首次使用：自动下载/校验模型（进度可见，下载到用户数据目录）
  ├─ 流水线：提取音轨 → 分离人声/伴奏 → 语音识别(带分句时间戳)
  │         → 逐句 TTS 生成新语音 → ffmpeg 按时间槽替换 → 混回伴奏 → 封装输出
  └─ 完成后在输出目录打开/定位结果文件
```

### 1.4 技术流程（离线）

```
输入视频
  └─ ffmpeg: 提取音频 → 44.1k/48k 立体声 wav（保留原采样率）
       └─ sherpa-onnx-offline-source-separation（内置 CLI）
            ├─ vocals.wav          ──→ VAD(silero) 分句 → ASR(SenseVoice)
            │                              └─ 每句文本 + 起止时间戳
            └─ accompaniment.wav   ──→ 保留，不识别
                                          │
                     TTS 目标音色逐句合成（Kokoro-zh 预设 / ZipVoice 克隆）
                                          │
                     ffmpeg: 新句按原时间槽放置（adelay+amix）
                                          │
                     ffmpeg: 新语音轨 + 伴奏轨混音 → 替换原音轨 → -c:v copy 封装
                                          ▼
                                 输出换声视频
```

### 1.5 关键实现点

- **背景音乐保留**：分离出的人声轨才被识别/替换，伴奏轨原样保留，最终混音回填。
- **句长不一致**：TTS 生成句长通常与原句不同。MVP 策略为「按时间槽放置 + 句尾对齐到下一句起点」：每句以 `adelay` 放到原句起点，若新句更长，则截断并提示；若更短，剩余静音由 `amix` 自然补齐；单句首尾做 20ms 淡入淡出避免爆音。二期再做 time-stretch 变速对齐。
- **模型按需下载**：首次使用下载到用户数据目录（macOS 默认 `~/Library/Application Support/hiext_yt_gui`，模型文件在其下 `models/<id>`；Linux/Windows 对应平台目录），记录 sha256 校验，不随安装包内置、不提交仓库。
- **完全离线**：推理、分离、识别、合成全部本地完成，无任何上传。

## 2. 技术选型与模型清单

### 2.1 引擎

| 环节 | 方案 | 说明 |
|---|---|---|
| 识别 ASR | `sherpa_onnx` Dart API（`OfflineRecognizer`） | 官方 Flutter 插件 1.13.4，macOS/Linux/Windows x64+arm64 |
| 合成 TTS | `sherpa_onnx` Dart API（`OfflineTts`） | 预设 Kokoro-zh；克隆 ZipVoice（Dart API 已支持零样本） |
| VAD 分句 | `sherpa_onnx` Dart API（silero-vad） | 用于把长音频切成句子级片段并取时间戳 |
| 人声/伴奏分离 | `sherpa-onnx-offline-source-separation` CLI（内置二进制） | Dart API 暂未暴露分离类（已核实包源码），CLI 走与 yt-dlp/ffmpeg 一致的内置工具机制 |
| 音频组装 | 仓库内置 ffmpeg | 提取、缩放、放置、混音、封装 |

### 2.2 模型清单（全部在首次使用时下载，不随包分发）

| 模型 | 用途 | 来源 | 体积 | 许可 | 商用结论 |
|---|---|---|---|---|---|
| UVR_MDXNET_1_9703.onnx | 人声/伴奏分离（首选） | k2-fsa `source-separation-models` | 28.3 MB | UVR5 声明 MIT+署名 | ✅ 商用需署名 UVR |
| sherpa-onnx-spleeter-2stems-fp16 | 分离备选（更轻、效果一般） | 同上 | 33.6 MB | 代码 MIT；权重许可声明模糊 | ⚠️ 默认不用 |
| SenseVoice int8（zh-en-ja-ko-yue） | ASR（多语言+中文方言，带 ITN） | k2-fsa `asr-models` | 155.5 MB | 代码 MIT；权重 FunASR 模型许可，官方澄清可商用 | ✅ 保留模型名署名 |
| Paraformer-zh-small int8 | ASR 备选（更小） | k2-fsa `asr-models` | 74.3 MB | MIT/Apache-2.0（按模型卡） | ✅ |
| silero-vad | 分句取时间戳 | sherpa-onnx `vad-models` | ~1 MB | MIT | ✅ |
| Kokoro 多语言 int8（含中文） | 内置预设音色 | k2-fsa `tts-models` | 140.2 MB | Apache-2.0 | ✅ 默认预设 |
| Matcha-zh（baker） | 预设备选 | k2-fsa `tts-models` | 72+51 MB | Baker 语料**仅限非商用** | ⚠️ 仅个人使用 |
| ZipVoice distill-int8（zh-en） | 零样本声音克隆（v1.1） | k2-fsa `tts-models` | 104+52 MB | 仓库 Apache-2.0 | ✅ 需 8GB+ 内存建议 |
| vocos-22khz-univ / vocos_24khz | TTS vocoder | k2-fsa `vocoder-models` | 51.4/51.6 MB | Apache-2.0（按 sherpa-onnx 发行） | ✅ |

**默认首启下载量**：分离 28.3 + VAD ~1 + ASR 155.5 + TTS 140.2 ≈ **325 MB**；克隆功能再加约 156 MB。

### 2.3 依赖新增

- `sherpa_onnx: ^1.13.4`（ASR/TTS/VAD 原生推理，含各平台原生库）
- `record: ^7.1.1`（录制参考音频，v1.1 使用；macOS 走 AVFoundation）
- `file_picker: ^11.0.3`（选视频、上传参考音频）

## 3. 架构与模块划分

```
lib/core/services/voice_swap/
  voice_swap_model_catalog.dart    模型元数据清单（id/url/sha256/size/license）
  voice_swap_model_manager.dart    下载/校验/解压到用户模型目录（复用内置工具 checksum 模式）
  voice_swap_settings.dart         换声设置模型（模型目录、默认音色、开关）
  sherpa_onnx_engine.dart          ASR/TTS/VAD 初始化与调用封装（单例，惰性初始化）
  source_separation_executor.dart  解析并调用 sherpa-onnx-offline-source-separation
  voice_swap_audio_assembler.dart  ffmpeg：提取/分句放置/混音/封装（纯命令构造，可单测）
  voice_swap_pipeline.dart         编排流水线 + 进度回调
lib/core/controllers/
  voice_swap_controller.dart       页面状态机（idle/downloading/separating/transcribing/
                                  synthesizing/mixing/done/failed + 进度 + 取消）
lib/features/voice_swap/
  voice_swap_page.dart             换声页面 UI
lib/core/models/
  voice_swap_models.dart           领域模型（任务、句段、结果）
```

工具/二进制解析顺序（沿用仓库既有规则）：
**设置页已验证路径 > 系统 PATH 与平台常见目录 > `assets/bin/<platform>`**。
分离 CLI 与 ffmpeg 都按此顺序解析；找不到时必须给出明确提示（设置路径/系统安装/刷新内置包），不能静默失败。

## 4. 配置与上线准备

### 4.1 设置项（`DownloadSettings` 之外独立持久化，key 前缀 `voice_swap.`）

示例（JSON，properties 语义）：

```jsonc
{
  "voice_swap.model_dir": "/Users/you/Library/Application Support/hiext_yt_gui",
  // 必选？否。默认：平台应用数据目录（macOS 为上述路径）。留空则用默认；
  // 目录下包含 downloads/、.checksums/、models/<id>/，可指向已有模型缓存根目录。
  "voice_swap.preset_voice": "kokoro-zf-xiaobei",
  // 必选？否。默认：kokoro-zf-xiaobei（Kokoro 中文女声）。可选：内置 8 个
  // kokoro-zf-*/kokoro-zm-* 预设备色；matcha-zh(仅个人) / zipvoice(克隆，v1.1) 为预留。
  "voice_swap.auto_download_models": true,
  // 必选？否。默认：true。关闭后若模型缺失则提示手动下载/放置。
  "voice_swap.separation_engine": "uvr",
  // 必选？否。默认：uvr。可选：uvr / spleeter（内部模型 id，不暴露 UI）。
  "voice_swap.separation_bin_path": "",
  // 必选？否。默认：按解析顺序自动查找。与 ffmpegPath 同语义的高级设置。
}
```

### 4.2 平台配置

| 平台 | 配置 |
|---|---|
| macOS | `macos/Runner/Info.plist` 增加 `NSMicrophoneUsageDescription`；`DebugProfile.entitlements` / `Release.entitlements` 增加 `com.apple.security.device.audio-input`（录制参考音频用） |
| Windows | 无额外配置；内置 `sherpa-onnx-offline-source-separation.exe` 与 DLL 随 `assets/bin/windows/` |
| Linux | 无额外配置；依赖系统 `libonnxruntime` 已静态打包进共享包，运行时仅需 glibc 基础环境 |

### 4.3 内置工具锁定（embedded_tools）

在 `tools/embedded_tools.lock.json` 新增 3 个 artifact（沿用 sha256/不提交二进制机制）：

| id | 平台 | 包 | 提取内容 |
|---|---|---|---|
| sherpa-onnx-sep-macos | macos | `sherpa-onnx-v1.13.4-osx-universal2-shared.tar.bz2` | `bin/sherpa-onnx-offline-source-separation` + `lib/*.dylib` |
| sherpa-onnx-sep-linux | linux | `sherpa-onnx-v1.13.4-linux-x64-shared.tar.bz2` | `bin/sherpa-onnx-offline-source-separation` + `lib/*.so` |
| sherpa-onnx-sep-windows | windows | `sherpa-onnx-v1.13.4-win-x64-shared-MD-Release.tar.bz2` | `bin/sherpa-onnx-offline-source-separation.exe` + DLL |

`tools/fetch_embedded_tools.dart` 需支持「tar.bz2 + 提取 bin 与 lib + 保留相对路径」。

### 4.4 上线材料清单

- [x] 模型 sha256 回填：首次下载时计算并写入 `.checksums/<id>.sha256` sidecar（UVR 已锁定，其余由 manager 自动回填）
- [x] `docs/third-party-tools.md` 补充 sherpa-onnx 分离 CLI、模型权重许可与署名要求
- [x] README 补充换声功能说明与「首次使用需下载约 325MB 模型」提示
- [x] 中英文 ARB 文案齐全
- [ ] macOS 签名/公证脚本确认不含模型目录（模型在用户数据目录，不进 bundle）

## 5. 预期代码修改面与 Task/Change 双向覆盖门禁

每个 Task 必须至少产生一个 Change；每个 Change 必须归属某个 Task（双向覆盖）。实施完成后按表核对，不允许出现「有 Task 无 Change」或「有 Change 无 Task」。

| Task | 说明 | Change ID | 涉及文件 |
|---|---|---|---|
| T1 设置与配置 | 换声设置模型、持久化、设置页入口 | C1 | `lib/core/models/voice_swap_models.dart`(新，含 `VoiceSwapSettings`)、`lib/core/models/app_models.dart`（`DownloadSettings.voiceSwap`）、`lib/features/settings/settings_page.dart`、`lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb` |
| T2 内置分离 CLI | 分离 CLI 三平台接入锁文件与 fetch 工具 | C2 | `tools/embedded_tools.lock.json`、`tools/fetch_embedded_tools.dart`、`lib/core/services/embedded_tool_manifest.dart`、`lib/core/services/embedded_tool_resolver.dart`、`lib/core/services/embedded_tool_executable.dart` |
| T3 模型管理 | 模型清单、下载/校验/解压、缺失提示 | C3 | `lib/core/services/voice_swap/voice_swap_model_catalog.dart`(新)、`voice_swap_model_manager.dart`(新) |
| T4 sherpa 引擎 | ASR/TTS/VAD 初始化与调用封装 | C4 | `lib/core/services/voice_swap/sherpa_onnx_engine.dart`(新) |
| T5 分离执行器 | 解析并调用分离 CLI | C5 | `lib/core/services/voice_swap/source_separation_executor.dart`(新) |
| T6 音频组装 | ffmpeg 提取/分句放置/混音/封装 | C6 | `lib/core/services/voice_swap/voice_swap_audio_assembler.dart`(新) |
| T7 流水线与控制器 | 编排 + 状态机 + 取消 | C7 | `lib/core/services/voice_swap/voice_swap_pipeline.dart`(新)、`lib/core/controllers/voice_swap_controller.dart`(新) |
| T8 页面 UI | 换声页面、导航接入、i18n | C8 | `lib/features/voice_swap/voice_swap_page.dart`(新)、`lib/features/voice_swap/voice_swap_preset_labels.dart`(新)、`lib/app/app_shell.dart`、`lib/l10n/*.arb` |
| T9 平台配置 | macOS 麦克风权限 | C9 | `macos/Runner/Info.plist`、`macos/Runner/DebugProfile.entitlements`、`macos/Runner/Release.entitlements` |
| T10 测试与文档 | 单测、README、第三方工具文档 | C10 | `test/core/services/voice_swap/*_test.dart`(新)、`docs/third-party-tools.md`、`README.md` |

## 6. 分阶段里程碑

- **M1（本期 MVP）**：T1–T10，预设音色换声全链路跑通（Kokoro-zh；上传视频；保留伴奏）。
- **M2（v1.1）**：录制/上传参考音频 + ZipVoice 零样本克隆（T3/T4 扩模型、页面扩「目标声音来源」交互、`record` 依赖启用）。
- **M3（未来规划）**：实时变声（RVC 等），本期不实现、不建分支。

## 7. 测试与验收

- 单测（不依赖真实模型/网络）：
  - `VoiceSwapAudioAssembler`：命令构造（提取、adelay 放置、amix、封装）、句长截断策略、时间槽计算。
  - `VoiceSwapModelManager`：目录解析、checksum 校验失败处理、解压产物校验。
  - `VoiceSwapController`：状态机流转与取消。
  - `SourceSeparationExecutor`：解析顺序（设置路径 > PATH > assets/bin）与缺失提示。
- 集成验收（本机手动，记录结果）：
  - 一个真实视频（带人声+背景音乐）跑通：输出视频人声被替换、伴奏完整保留、音画同步可接受。
  - 断网重跑：模型已缓存时全程离线可用。
- 提交前：`flutter analyze --no-fatal-infos` + `flutter test` 通过。

## 8. 风险与注意事项

- **许可**：Matcha-zh(baker) 仅限非商用，默认不选；UVR 模型商用需保留署名；SenseVoice 需按 FunASR 模型许可保留模型名。正式发布前需在 `docs/third-party-tools.md` 固化署名与声明。
- **性能**：325MB 模型首次下载 + 分离/识别/合成耗时（CPU 推理）。MVP 允许分钟级处理；实时性不在本期。
- **音画同步**：句长不一致是最大质量风险，MVP 用时间槽截断策略兜底，二期做变速对齐。
- **内存**：ZipVoice 官方建议 8GB+，克隆功能需在 UI 提示。
- **模型目录**：不提交仓库、不进 bundle；清理策略（删除旧模型）二期再做。
