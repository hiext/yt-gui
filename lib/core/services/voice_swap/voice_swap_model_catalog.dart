import '../../models/voice_swap_models.dart';

/// 内置预设备色（Kokoro 多语言 v1_0，中文 sid 已由官方文档确认）。
class VoiceSwapPresetVoice {
  const VoiceSwapPresetVoice({
    required this.id,
    required this.modelId,
    required this.sid,
    required this.nameKey,
    required this.genderKey,
  });

  final String id;
  final String modelId;
  final int sid;
  final String nameKey;
  final String genderKey;
}

/// 换声模型与预设备色清单。
///
/// 模型统一在首次使用时下载到用户模型目录（[VoiceSwapSettings.resolvedModelDir]），
/// 不随安装包分发、不提交仓库。sha256 为可选；为空时由
/// [VoiceSwapModelManager] 在首次下载后计算并缓存到 sidecar 文件。
class VoiceSwapModelCatalog {
  const VoiceSwapModelCatalog();

  static const models = <String, VoiceSwapModelFile>{
    // 人声/伴奏分离（首选，UVR-MDX-Net 1 号模型）。
    'uvr': VoiceSwapModelFile(
      id: 'uvr',
      name: 'UVR_MDXNET_1_9703',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/source-separation-models/UVR_MDXNET_1_9703.onnx',
      sizeBytes: 29704740,
      license: 'MIT（保留 UVR 署名）',
    ),
    // 分离备选：spleeter 2stems fp16（效果一般，默认不用）。
    'spleeter-fp16': VoiceSwapModelFile(
      id: 'spleeter-fp16',
      name: 'sherpa-onnx-spleeter-2stems-fp16',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/source-separation-models/sherpa-onnx-spleeter-2stems-fp16.tar.bz2',
      sizeBytes: 35271738,
      license: '代码 MIT；权重许可声明模糊',
      archive: true,
    ),
    // VAD 分句取时间戳。
    'vad': VoiceSwapModelFile(
      id: 'vad',
      name: 'silero_vad',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
      sizeBytes: 643854,
      license: 'MIT',
    ),
    // 语音识别（SenseVoice int8，多语言含中文方言，带 ITN）。
    'asr-sensevoice': VoiceSwapModelFile(
      id: 'asr-sensevoice',
      name: 'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2',
      sizeBytes: 163002883,
      license: '代码 MIT；权重遵循 FunASR 模型许可，保留模型名',
      archive: true,
    ),
    // ASR 备选（更小）。
    'asr-paraformer-zh-small': VoiceSwapModelFile(
      id: 'asr-paraformer-zh-small',
      name: 'sherpa-onnx-paraformer-zh-small',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2',
      sizeBytes: 77920048,
      license: 'MIT / Apache-2.0（按模型卡）',
      archive: true,
    ),
    // 内置预设备色（Kokoro 多语言 int8 v1_0，中文 sid 45-52）。
    'tts-kokoro': VoiceSwapModelFile(
      id: 'tts-kokoro',
      name: 'kokoro-int8-multi-lang-v1_0',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2',
      sizeBytes: 131839838,
      license: 'Apache-2.0',
      archive: true,
    ),
    // 备选预设（baker 语料仅限非商用，默认不选）。
    'tts-matcha-zh': VoiceSwapModelFile(
      id: 'tts-matcha-zh',
      name: 'matcha-icefall-zh-baker',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/matcha-icefall-zh-baker.tar.bz2',
      sizeBytes: 75463442,
      license: 'baker 语料仅限非商用',
      archive: true,
    ),
    // 声音克隆（v1.1）：ZipVoice distill int8。
    'tts-zipvoice': VoiceSwapModelFile(
      id: 'tts-zipvoice',
      name: 'sherpa-onnx-zipvoice-distill-int8-zh-en-emilia',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/sherpa-onnx-zipvoice-distill-int8-zh-en-emilia.tar.bz2',
      sizeBytes: 109162785,
      license: 'Apache-2.0',
      archive: true,
    ),
    // 克隆 vocoder（v1.1）。
    'vocoder-vocos': VoiceSwapModelFile(
      id: 'vocoder-vocos',
      name: 'vocos_24khz',
      url:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/vocoder-models/vocos_24khz.onnx',
      sizeBytes: 54157409,
      license: 'Apache-2.0（按 sherpa-onnx 发行）',
    ),
  };

  /// 内置预设备色：Kokoro v1_0 中文说话人。
  static const presetVoices = <VoiceSwapPresetVoice>[
    VoiceSwapPresetVoice(
      id: 'kokoro-zf-xiaobei',
      modelId: 'tts-kokoro',
      sid: 45,
      nameKey: 'voiceSwapPresetZfXiaobei',
      genderKey: 'voiceSwapPresetFemale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zf-xiaoni',
      modelId: 'tts-kokoro',
      sid: 46,
      nameKey: 'voiceSwapPresetZfXiaoni',
      genderKey: 'voiceSwapPresetFemale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zf-xiaoxiao',
      modelId: 'tts-kokoro',
      sid: 47,
      nameKey: 'voiceSwapPresetZfXiaoxiao',
      genderKey: 'voiceSwapPresetFemale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zf-xiaoyi',
      modelId: 'tts-kokoro',
      sid: 48,
      nameKey: 'voiceSwapPresetZfXiaoyi',
      genderKey: 'voiceSwapPresetFemale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zm-yunjian',
      modelId: 'tts-kokoro',
      sid: 49,
      nameKey: 'voiceSwapPresetZmYunjian',
      genderKey: 'voiceSwapPresetMale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zm-yunxi',
      modelId: 'tts-kokoro',
      sid: 50,
      nameKey: 'voiceSwapPresetZmYunxi',
      genderKey: 'voiceSwapPresetMale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zm-yunxia',
      modelId: 'tts-kokoro',
      sid: 51,
      nameKey: 'voiceSwapPresetZmYunxia',
      genderKey: 'voiceSwapPresetMale',
    ),
    VoiceSwapPresetVoice(
      id: 'kokoro-zm-yunyang',
      modelId: 'tts-kokoro',
      sid: 52,
      nameKey: 'voiceSwapPresetZmYunyang',
      genderKey: 'voiceSwapPresetMale',
    ),
  ];

  /// MVP 默认模型集合（分离 + VAD + ASR + TTS）。
  static List<String> defaultModelIds({bool withClone = false}) => [
    'uvr',
    'vad',
    'asr-sensevoice',
    'tts-kokoro',
    if (withClone) ...['tts-zipvoice', 'vocoder-vocos'],
  ];

  static VoiceSwapModelFile modelOf(String id) {
    final model = models[id];
    if (model == null) {
      throw VoiceSwapModelCatalogException('Unknown model id: $id');
    }
    return model;
  }

  static VoiceSwapPresetVoice presetVoiceOf(String id) {
    for (final voice in presetVoices) {
      if (voice.id == id) return voice;
    }
    throw VoiceSwapModelCatalogException('Unknown preset voice id: $id');
  }
}

class VoiceSwapModelCatalogException implements Exception {
  const VoiceSwapModelCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
