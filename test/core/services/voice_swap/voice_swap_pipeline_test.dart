import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/models/voice_swap_models.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/sherpa_onnx_engine.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/source_separation_executor.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_audio_assembler.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_model_catalog.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_model_manager.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_pipeline.dart';

class _FakeModelManager implements VoiceSwapModelManager {
  _FakeModelManager({this.ensureIds});

  final List<String>? ensureIds;
  bool cancelled = false;

  @override
  VoiceSwapSettings get settings => VoiceSwapSettings.defaults;

  @override
  VoiceSwapModelCatalog get catalog => const VoiceSwapModelCatalog();

  @override
  String get modelDir => '/tmp/fake-models';

  @override
  String downloadPath(String id) => '/tmp/fake-models/downloads/$id';

  @override
  String modelRoot(String id) => '/tmp/fake-models/models/$id';

  @override
  String checksumPath(String id) => '/tmp/fake-models/.checksums/$id.sha256';

  @override
  Future<bool> isAvailable(String id) async => true;

  @override
  Future<VoiceSwapModelFile> ensureAvailable(
    String id, {
    bool autoDownload = true,
    void Function(VoiceSwapProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) {
      cancelled = true;
      throw const VoiceSwapCancelledException();
    }
    return VoiceSwapModelCatalog.modelOf(id);
  }

  @override
  Future<List<VoiceSwapModelFile>> ensureModels(
    List<String> ids, {
    bool autoDownload = true,
    void Function(VoiceSwapProgress progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    ensureIds?.addAll(ids);
    final result = <VoiceSwapModelFile>[];
    for (var i = 0; i < ids.length; i++) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        throw const VoiceSwapCancelledException();
      }
      result.add(VoiceSwapModelCatalog.modelOf(ids[i]));
    }
    return result;
  }

  @override
  String? resolveFilePath(String id) => '/tmp/fake-models/uvr.onnx';

  @override
  String? resolveDir(String id) => null;

  @override
  String? resolveDirInModel(String id, {required String dirName}) => null;

  @override
  String? resolveFileInDir(String id, {required List<String> candidateNames}) {
    if (candidateNames.isEmpty) return null;
    return '$modelRoot/$id/${candidateNames.first}';
  }
}

class _FakeSeparationExecutor implements SourceSeparationExecutor {
  _FakeSeparationExecutor();

  @override
  Future<ResolvedSeparationCli> resolveCli({
    required VoiceSwapSettings settings,
  }) async {
    return const ResolvedSeparationCli(path: '/bin/sep', isCustom: true);
  }

  @override
  Future<SeparationOutput> separate({
    required ResolvedSeparationCli cli,
    required String inputWav,
    required String outputVocalsWav,
    required String outputAccompanimentWav,
    required String uvrModelPath,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) {
      throw const VoiceSwapCancelledException();
    }
    return SeparationOutput(
      vocalsWav: outputVocalsWav,
      accompanimentWav: outputAccompanimentWav,
    );
  }

  @override
  void cancel() {}
}

class _FakeEngine implements SherpaOnnxEngine {
  _FakeEngine({
    this.sentences = const [
      VoiceSwapSentence(text: '你好', startMs: 0, endMs: 1000),
      VoiceSwapSentence(text: '世界', startMs: 2000, endMs: 3000),
    ],
  });

  final List<VoiceSwapSentence> sentences;
  bool loaded = false;
  int synthesizeCount = 0;

  @override
  bool get isLoaded => loaded;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> load({required VoiceSwapModelPaths paths}) async {
    loaded = true;
  }

  @override
  Future<List<VoiceSwapSentence>> transcribeWav({
    required String wavPath,
  }) async {
    return sentences;
  }

  @override
  List<VoiceSwapSentence> transcribeSamples(
    Float32List samples, {
    required int sampleRate,
  }) {
    return sentences;
  }

  @override
  SynthesizedSpeech synthesize({required String text, int sid = 0}) {
    synthesizeCount++;
    return SynthesizedSpeech(samples: Float32List(16000), sampleRate: 16000);
  }

  @override
  void dispose() {}
}

class _FakeAssembler implements VoiceSwapAudioAssembler {
  _FakeAssembler();

  bool muxed = false;
  bool cancelled = false;

  @override
  Future<String> extractAudioWav({
    required String sourceVideo,
    required String outputWav,
    required DownloadSettings settings,
  }) async {
    return outputWav;
  }

  @override
  Future<String> resampleTo16kMono({
    required String inputWav,
    required String outputWav,
    required DownloadSettings settings,
  }) async {
    // 流水线会用 wav 头计算时长：44 字节头 + 1s * 16k * 2 字节。
    File(outputWav)
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(44 + 32000, 0));
    return outputWav;
  }

  @override
  Future<void> placeSentences({
    required List<String> ttsWavs,
    required List<int> startMsList,
    required List<int> slotMsList,
    required String outputDir,
    required DownloadSettings settings,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) {
      throw const VoiceSwapCancelledException();
    }
  }

  @override
  Future<String> mixSentencesWithAccompaniment({
    required String accompanimentWav,
    required List<String> placedWavs,
    required String outputWav,
    required DownloadSettings settings,
  }) async {
    return outputWav;
  }

  @override
  Future<String> muxVideoWithAudio({
    required String sourceVideo,
    required String mixedWav,
    required String outputVideo,
    required DownloadSettings settings,
  }) async {
    muxed = true;
    return outputVideo;
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

VoiceSwapPipeline _pipeline({
  _FakeModelManager? manager,
  _FakeSeparationExecutor? separation,
  _FakeEngine? engine,
  _FakeAssembler? assembler,
  String? tempDir,
}) {
  return VoiceSwapPipeline(
    modelManager: manager ?? _FakeModelManager(),
    separationExecutor: separation ?? _FakeSeparationExecutor(),
    engine: engine ?? _FakeEngine(),
    assembler: assembler ?? _FakeAssembler(),
    downloadSettings: DownloadSettings.defaults,
    voiceSwapSettings: const VoiceSwapSettings(),
    tempDirFactory: () => tempDir ?? '/tmp/voice-swap-work',
  );
}

void main() {
  final inputVideo = '/tmp/in/video.mp4';
  final outputVideo = '/tmp/out/result.mp4';
  Directory('/tmp/out').createSync(recursive: true);

  tearDown(() {
    final dir = Directory('/tmp/voice-swap-work');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('VoiceSwapPipeline', () {
    test('完整流程按顺序执行并返回结果', () async {
      final manager = _FakeModelManager();
      final separation = _FakeSeparationExecutor();
      final engine = _FakeEngine();
      final assembler = _FakeAssembler();
      final pipeline = _pipeline(
        manager: manager,
        separation: separation,
        engine: engine,
        assembler: assembler,
      );

      final stages = <VoiceSwapStage>[];
      final result = await pipeline.run(
        inputVideo: inputVideo,
        outputVideo: outputVideo,
        presetVoiceId: 'kokoro-zf-xiaobei',
        onProgress: (p) => stages.add(p.stage),
      );

      expect(engine.loaded, isTrue);
      expect(engine.synthesizeCount, 2);
      expect(assembler.muxed, isTrue);
      expect(result.sentenceCount, 2);
      expect(result.outputPath, outputVideo);
      expect(stages.first, VoiceSwapStage.downloadingModels);
      expect(stages.last, VoiceSwapStage.done);
    });

    test('识别不到人声时抛出明确异常', () async {
      final pipeline = _pipeline(engine: _FakeEngine(sentences: const []));

      expect(
        () => pipeline.run(
          inputVideo: inputVideo,
          outputVideo: outputVideo,
          presetVoiceId: 'kokoro-zf-xiaobei',
          onProgress: (_) {},
        ),
        throwsA(isA<VoiceSwapPipelineException>()),
      );
    });

    test('默认模型集合为 uvr/vad/asr-sensevoice/tts-kokoro', () async {
      final manager = _FakeModelManager(ensureIds: []);
      final pipeline = _pipeline(manager: manager);

      await pipeline.run(
        inputVideo: inputVideo,
        outputVideo: outputVideo,
        presetVoiceId: 'kokoro-zf-xiaobei',
        onProgress: (_) {},
      );

      expect(
        manager.ensureIds,
        containsAllInOrder(['uvr', 'vad', 'asr-sensevoice', 'tts-kokoro']),
      );
    });
  });
}
