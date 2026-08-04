import 'dart:convert';
import 'dart:io';

/// 换声功能独立设置，持久化在 DownloadSettings.voiceSwap 下。
class VoiceSwapSettings {
  const VoiceSwapSettings({
    this.modelDir,
    this.presetVoice = 'kokoro-zf-xiaobei',
    this.autoDownloadModels = true,
    this.separationEngine = 'uvr',
    this.separationBinPath,
  });

  static const defaults = VoiceSwapSettings();

  /// 模型缓存根目录；为空时使用平台默认目录。
  final String? modelDir;

  /// 内置预设音色 id，见 VoiceSwapModelCatalog.presetVoices。
  final String presetVoice;

  /// 首次使用是否自动下载模型；关闭后缺失模型直接报错提示。
  final bool autoDownloadModels;

  /// 分离引擎：uvr / spleeter。
  final String separationEngine;

  /// 分离 CLI 自定义路径（设置页优先级最高，与 ffmpegPath 同语义）。
  final String? separationBinPath;

  factory VoiceSwapSettings.fromJson(Object? json) {
    Map<String, Object?> map;
    if (json is Map) {
      map = Map<String, Object?>.from(json);
    } else if (json is String) {
      try {
        map = Map<String, Object?>.from(jsonDecode(json) as Map);
      } catch (_) {
        return defaults;
      }
    } else {
      return defaults;
    }

    String? trimOrNull(Object? v) {
      if (v is! String) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    return VoiceSwapSettings(
      modelDir: trimOrNull(map['modelDir']),
      presetVoice: trimOrNull(map['presetVoice']) ?? defaults.presetVoice,
      autoDownloadModels: map['autoDownloadModels'] is bool
          ? map['autoDownloadModels'] as bool
          : defaults.autoDownloadModels,
      separationEngine:
          trimOrNull(map['separationEngine']) ?? defaults.separationEngine,
      separationBinPath: trimOrNull(map['separationBinPath']),
    );
  }

  Map<String, Object?> toJson() => {
    if (modelDir != null) 'modelDir': modelDir,
    'presetVoice': presetVoice,
    'autoDownloadModels': autoDownloadModels,
    'separationEngine': separationEngine,
    if (separationBinPath != null) 'separationBinPath': separationBinPath,
  };

  VoiceSwapSettings copyWith({
    Object? modelDir = _unchanged,
    Object? presetVoice = _unchanged,
    Object? autoDownloadModels = _unchanged,
    Object? separationEngine = _unchanged,
    Object? separationBinPath = _unchanged,
  }) {
    return VoiceSwapSettings(
      modelDir: modelDir == _unchanged ? this.modelDir : modelDir as String?,
      presetVoice: presetVoice == _unchanged
          ? this.presetVoice
          : presetVoice as String,
      autoDownloadModels: autoDownloadModels == _unchanged
          ? this.autoDownloadModels
          : autoDownloadModels as bool,
      separationEngine: separationEngine == _unchanged
          ? this.separationEngine
          : separationEngine as String,
      separationBinPath: separationBinPath == _unchanged
          ? this.separationBinPath
          : separationBinPath as String?,
    );
  }

  /// 生效的模型数据根目录；未配置时用平台默认（应用数据目录）。
  ///
  /// 根目录下包含 `downloads/`、`.checksums/`、`models/<id>/`，
  /// 具体布局见 [VoiceSwapModelManager]。
  String get resolvedModelDir {
    final custom = modelDir?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/hiext_yt_gui';
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['LOCALAPPDATA'] ?? home;
      return '$appData\\hiext_yt_gui';
    }
    return '$home/.local/share/hiext_yt_gui';
  }
}

const Object _unchanged = Object();

/// 模型文件元数据（用于下载、校验与许可说明）。
class VoiceSwapModelFile {
  const VoiceSwapModelFile({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeBytes,
    required this.license,
    this.sha256,
    this.archive = false,
  });

  final String id;
  final String name;
  final String url;
  final int sizeBytes;
  final String license;
  final String? sha256;

  /// true 表示 tar.bz2 压缩包，下载后解压到模型目录。
  final bool archive;

  bool get needsVerify => sha256 != null;
}

/// VAD 分句结果：文本 + 原始音频内的起止毫秒。
class VoiceSwapSentence {
  const VoiceSwapSentence({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;
}

/// 流水线阶段。
enum VoiceSwapStage {
  idle,
  downloadingModels,
  extractingAudio,
  separating,
  transcribing,
  synthesizing,
  mixing,
  done,
  failed,
  cancelled,
}

/// 进度回调载荷。
class VoiceSwapProgress {
  const VoiceSwapProgress({
    required this.stage,
    this.progress = 0,
    this.message,
  });

  final VoiceSwapStage stage;
  final double progress;
  final String? message;
}

/// 换声结果。
class VoiceSwapResult {
  const VoiceSwapResult({
    required this.outputPath,
    required this.sentenceCount,
    required this.durationMs,
  });

  final String outputPath;
  final int sentenceCount;
  final int durationMs;
}
