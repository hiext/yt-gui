import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../models/voice_swap_models.dart';
import 'voice_swap_model_manager.dart';

/// 解析好的模型路径集合，由 [VoiceSwapModelPaths.resolve] 从模型管理器生成。
class VoiceSwapModelPaths {
  const VoiceSwapModelPaths({
    required this.vadModel,
    required this.asrModel,
    required this.asrTokens,
    this.ttsModel = '',
    this.ttsVoices = '',
    this.ttsTokens = '',
    this.ttsDataDir = '',
    this.ttsDictDir = '',
    this.ttsLexicon = '',
  });

  final String vadModel;
  final String asrModel;
  final String asrTokens;
  final String ttsModel;
  final String ttsVoices;
  final String ttsTokens;
  final String ttsDataDir;
  final String ttsDictDir;
  final String ttsLexicon;

  bool get hasTts => ttsModel.isNotEmpty;

  /// 从模型管理器解析 MVP 所需的 VAD/ASR/TTS 路径；缺失即抛异常。
  static VoiceSwapModelPaths resolve(
    VoiceSwapModelManager manager, {
    bool withTts = true,
  }) {
    final vad = manager.resolveFilePath('vad');
    if (vad == null) {
      throw VoiceSwapEngineException('缺少 VAD 模型（vad）');
    }
    final asrModel = manager.resolveFileInDir(
      'asr-sensevoice',
      candidateNames: const ['model.int8.onnx', 'model.onnx'],
    );
    final asrTokens = manager.resolveFileInDir(
      'asr-sensevoice',
      candidateNames: const ['tokens.txt'],
    );
    if (asrModel == null || asrTokens == null) {
      throw VoiceSwapEngineException('缺少 ASR 模型（asr-sensevoice）');
    }

    if (!withTts) {
      return VoiceSwapModelPaths(
        vadModel: vad,
        asrModel: asrModel,
        asrTokens: asrTokens,
      );
    }

    final ttsModel = manager.resolveFileInDir(
      'tts-kokoro',
      candidateNames: const ['model.int8.onnx', 'model.onnx'],
    );
    final ttsVoices = manager.resolveFileInDir(
      'tts-kokoro',
      candidateNames: const ['voices.bin'],
    );
    final ttsTokens = manager.resolveFileInDir(
      'tts-kokoro',
      candidateNames: const ['tokens.txt'],
    );
    final ttsDataDir = manager.resolveDirInModel(
      'tts-kokoro',
      dirName: 'espeak-ng-data',
    );
    final ttsDictDir = manager.resolveDirInModel('tts-kokoro', dirName: 'dict');
    if (ttsModel == null || ttsVoices == null || ttsTokens == null) {
      throw VoiceSwapEngineException('缺少 TTS 模型（tts-kokoro）');
    }
    final lexEn = manager.resolveFileInDir(
      'tts-kokoro',
      candidateNames: const ['lexicon-us-en.txt'],
    );
    final lexZh = manager.resolveFileInDir(
      'tts-kokoro',
      candidateNames: const ['lexicon-zh.txt'],
    );

    return VoiceSwapModelPaths(
      vadModel: vad,
      asrModel: asrModel,
      asrTokens: asrTokens,
      ttsModel: ttsModel,
      ttsVoices: ttsVoices,
      ttsTokens: ttsTokens,
      ttsDataDir: ttsDataDir ?? '',
      ttsDictDir: ttsDictDir ?? '',
      ttsLexicon: [?lexEn, ?lexZh].join(','),
    );
  }
}

/// TTS 合成结果（内存 PCM）。
class SynthesizedSpeech {
  const SynthesizedSpeech({required this.samples, required this.sampleRate});

  final Float32List samples;
  final int sampleRate;

  int get durationMs =>
      sampleRate == 0 ? 0 : (samples.length * 1000 / sampleRate).round();
}

/// sherpa-onnx 引擎封装：VAD 分句 + SenseVoice ASR + Kokoro TTS。
///
/// 懒加载单例式使用：先 [ensureInitialized]，再 [load]（解析模型路径），
/// 之后可重复调用 [transcribeWav] 与 [synthesize]；结束调用 [dispose]。
class SherpaOnnxEngine {
  SherpaOnnxEngine({Future<void> Function()? initializeBindings})
    : _initializeBindings = initializeBindings ?? _defaultInitialize;

  final Future<void> Function() _initializeBindings;
  bool _initialized = false;
  bool _loaded = false;

  sherpa_onnx.VoiceActivityDetector? _vad;
  sherpa_onnx.OfflineRecognizer? _recognizer;
  sherpa_onnx.OfflineTts? _tts;

  bool get isLoaded => _loaded;

  static Future<void> _defaultInitialize() async {
    sherpa_onnx.initBindings();
  }

  /// 初始化原生绑定（进程内一次即可）。
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _initializeBindings();
    _initialized = true;
  }

  /// 加载 VAD/ASR/TTS 模型到内存。
  Future<void> load({required VoiceSwapModelPaths paths}) async {
    await ensureInitialized();
    if (_loaded) return;

    final vadConfig = sherpa_onnx.SileroVadModelConfig(
      model: paths.vadModel,
      minSilenceDuration: 0.25,
      minSpeechDuration: 0.5,
      maxSpeechDuration: 10.0,
    );
    _vad = sherpa_onnx.VoiceActivityDetector(
      config: sherpa_onnx.VadModelConfig(
        sileroVad: vadConfig,
        numThreads: 2,
        debug: false,
      ),
      bufferSizeInSeconds: 60,
    );

    _recognizer = sherpa_onnx.OfflineRecognizer(
      sherpa_onnx.OfflineRecognizerConfig(
        model: sherpa_onnx.OfflineModelConfig(
          senseVoice: sherpa_onnx.OfflineSenseVoiceModelConfig(
            model: paths.asrModel,
            language: 'auto',
            useInverseTextNormalization: true,
          ),
          tokens: paths.asrTokens,
          numThreads: 2,
          debug: false,
        ),
      ),
    );

    if (paths.hasTts) {
      _tts = sherpa_onnx.OfflineTts(
        sherpa_onnx.OfflineTtsConfig(
          model: sherpa_onnx.OfflineTtsModelConfig(
            kokoro: sherpa_onnx.OfflineTtsKokoroModelConfig(
              model: paths.ttsModel,
              voices: paths.ttsVoices,
              tokens: paths.ttsTokens,
              dataDir: paths.ttsDataDir,
              dictDir: paths.ttsDictDir,
              lexicon: paths.ttsLexicon,
              lengthScale: 1.0,
            ),
            numThreads: 2,
          ),
        ),
      );
    }
    _loaded = true;
  }

  /// 识别 16kHz 单声道 wav，返回带起止时间戳的分句。
  Future<List<VoiceSwapSentence>> transcribeWav({
    required String wavPath,
  }) async {
    final wave = sherpa_onnx.readWave(wavPath);
    if (wave.sampleRate != 16000) {
      throw VoiceSwapEngineException(
        'ASR 需要 16kHz 单声道 wav，实际采样率 ${wave.sampleRate}Hz',
      );
    }
    return transcribeSamples(wave.samples, sampleRate: wave.sampleRate);
  }

  /// VAD + ASR 分句（与官方 sense-voice.dart 示例同构）。
  List<VoiceSwapSentence> transcribeSamples(
    Float32List samples, {
    required int sampleRate,
  }) {
    final vad = _vad;
    final recognizer = _recognizer;
    if (vad == null || recognizer == null) {
      throw VoiceSwapEngineException('引擎未加载，请先调用 load()');
    }
    final result = <VoiceSwapSentence>[];
    final windowSize = vad.config.sileroVad.windowSize;

    void drain() {
      while (!vad.isEmpty()) {
        final segment = vad.front();
        final startMs = (segment.start * 1000 / sampleRate).round();
        final endMs =
            ((segment.start + segment.samples.length) * 1000 / sampleRate)
                .round();
        final stream = recognizer.createStream();
        stream.acceptWaveform(samples: segment.samples, sampleRate: sampleRate);
        recognizer.decode(stream);
        final text = recognizer.getResult(stream).text.trim();
        stream.free();
        vad.pop();
        if (text.isEmpty) continue;
        result.add(
          VoiceSwapSentence(text: text, startMs: startMs, endMs: endMs),
        );
      }
    }

    final numIter = samples.length ~/ windowSize;
    for (var i = 0; i < numIter; i++) {
      final start = i * windowSize;
      vad.acceptWaveform(
        Float32List.sublistView(samples, start, start + windowSize),
      );
      drain();
    }
    vad.flush();
    drain();
    return result;
  }

  /// 用当前音色合成一句语音。
  SynthesizedSpeech synthesize({required String text, int sid = 0}) {
    final tts = _tts;
    if (tts == null) {
      throw VoiceSwapEngineException('TTS 未加载，请先调用 load()');
    }
    final audio = tts.generate(text: text, sid: sid);
    return SynthesizedSpeech(
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
  }

  /// 释放原生资源；[ensureInitialized] 后可以再次 [load]。
  void dispose() {
    _vad?.free();
    _recognizer?.free();
    _tts?.free();
    _vad = null;
    _recognizer = null;
    _tts = null;
    _loaded = false;
  }
}

class VoiceSwapEngineException implements Exception {
  const VoiceSwapEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}
