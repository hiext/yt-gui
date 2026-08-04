import 'dart:io';

import '../../models/app_models.dart';
import '../../models/voice_swap_models.dart';
import '../log_service.dart';
import 'sherpa_onnx_engine.dart';
import 'source_separation_executor.dart';
import 'voice_swap_audio_assembler.dart';
import 'voice_swap_model_catalog.dart';
import 'voice_swap_model_manager.dart';

/// 换声流水线编排：模型就绪 → 提取音轨 → 分离 → 识别 → 逐句合成 → 混音 → 封装。
class VoiceSwapPipeline {
  VoiceSwapPipeline({
    required this.modelManager,
    required this.separationExecutor,
    required this.engine,
    required this.assembler,
    required this._downloadSettings,
    required this._voiceSwapSettings,
    String Function()? tempDirFactory,
  }) : _tempDirFactory = tempDirFactory ?? _defaultTempDir;

  final VoiceSwapModelManager modelManager;
  final SourceSeparationExecutor separationExecutor;
  final SherpaOnnxEngine engine;
  final VoiceSwapAudioAssembler assembler;
  final DownloadSettings _downloadSettings;
  final VoiceSwapSettings _voiceSwapSettings;
  final String Function() _tempDirFactory;

  /// 执行完整换声；[presetVoiceId] 为内置预设备色 id。
  Future<VoiceSwapResult> run({
    required String inputVideo,
    required String outputVideo,
    required String presetVoiceId,
    required void Function(VoiceSwapProgress progress) onProgress,
    bool Function()? isCancelled,
  }) async {
    final voice = VoiceSwapModelCatalog.presetVoiceOf(presetVoiceId);
    final workDir = _tempDirFactory();
    Directory(workDir).createSync(recursive: true);
    Directory(File(outputVideo).parent.path).createSync(recursive: true);

    void report(VoiceSwapStage stage, double progress, [String? message]) {
      onProgress(VoiceSwapProgress(stage: stage, progress: progress, message: message));
    }

    try {
      // 1. 模型就绪（首次自动下载，带进度）。
      report(
        VoiceSwapStage.downloadingModels,
        0,
        '准备模型（首次约 325MB，仅下载一次）',
      );
      await modelManager.ensureModels(
        VoiceSwapModelCatalog.defaultModelIds(),
        autoDownload: _voiceSwapSettings.autoDownloadModels,
        isCancelled: isCancelled,
        onProgress: onProgress,
      );
      final modelPaths = VoiceSwapModelPaths.resolve(modelManager);

      // 2. 提取音轨。
      report(VoiceSwapStage.extractingAudio, 0, '提取音轨');
      final audioWav =
          '$workDir${Platform.pathSeparator}audio.wav';
      await assembler.extractAudioWav(
        sourceVideo: inputVideo,
        outputWav: audioWav,
        settings: _downloadSettings,
      );

      // 3. 人声/伴奏分离。
      report(VoiceSwapStage.separating, 0, '分离人声与伴奏');
      final cli = await separationExecutor.resolveCli(
        settings: _voiceSwapSettings,
      );
      final uvrModel = modelManager.resolveFilePath('uvr');
      if (uvrModel == null) {
        throw VoiceSwapSeparationException('缺少分离模型（uvr），请重新下载模型');
      }
      final separation = await separationExecutor.separate(
        cli: cli,
        inputWav: audioWav,
        outputVocalsWav:
            '$workDir${Platform.pathSeparator}vocals.wav',
        outputAccompanimentWav:
            '$workDir${Platform.pathSeparator}accompaniment.wav',
        uvrModelPath: uvrModel,
        isCancelled: isCancelled,
      );

      // 4. 人声重采样为 16k 单声道并识别分句。
      report(VoiceSwapStage.transcribing, 0, '语音识别分句');
      final vocals16k =
          '$workDir${Platform.pathSeparator}vocals_16k.wav';
      await assembler.resampleTo16kMono(
        inputWav: separation.vocalsWav,
        outputWav: vocals16k,
        settings: _downloadSettings,
      );
      await engine.load(paths: modelPaths);
      final sentences = await engine.transcribeWav(wavPath: vocals16k);
      if (sentences.isEmpty) {
        throw VoiceSwapPipelineException('未识别到人声，请确认视频包含清晰语音');
      }
      final audioEndMs = _wav16kDurationMs(vocals16k);

      // 5. 逐句 TTS 合成。
      report(VoiceSwapStage.synthesizing, 0, '逐句合成新语音');
      final ttsWavs = <String>[];
      for (var i = 0; i < sentences.length; i++) {
        if (isCancelled?.call() ?? false) {
          throw VoiceSwapCancelledException();
        }
        final sentence = sentences[i];
        final speech = engine.synthesize(text: sentence.text, sid: voice.sid);
        final wav = '$workDir${Platform.pathSeparator}tts_$i.wav';
        writeMonoPcmWav(
          path: wav,
          samples: speech.samples,
          sampleRate: speech.sampleRate,
        );
        ttsWavs.add(wav);
        report(
          VoiceSwapStage.synthesizing,
          (i + 1) / sentences.length,
          '合成第 ${i + 1}/${sentences.length} 句',
        );
      }

      // 6. 按原时间槽放置并混入伴奏。
      report(VoiceSwapStage.mixing, 0, '按时间槽混音');
      final startMsList = <int>[];
      final slotMsList = <int>[];
      for (var i = 0; i < sentences.length; i++) {
        final start = sentences[i].startMs;
        final nextStart =
            i + 1 < sentences.length ? sentences[i + 1].startMs : audioEndMs;
        startMsList.add(start);
        slotMsList.add(
          VoiceSwapAudioAssembler.slotDurationMs(
            startMs: start,
            nextStartMs: nextStart,
            audioEndMs: audioEndMs,
          ),
        );
      }
      final placedDir =
          '$workDir${Platform.pathSeparator}placed';
      Directory(placedDir).createSync(recursive: true);
      await assembler.placeSentences(
        ttsWavs: ttsWavs,
        startMsList: startMsList,
        slotMsList: slotMsList,
        outputDir: placedDir,
        settings: _downloadSettings,
        isCancelled: isCancelled,
      );
      final mixedWav = '$workDir${Platform.pathSeparator}mixed.wav';
      await assembler.mixSentencesWithAccompaniment(
        accompanimentWav: separation.accompanimentWav,
        placedWavs: [
          for (var i = 0; i < ttsWavs.length; i++)
            '$placedDir${Platform.pathSeparator}placed_$i.wav',
        ],
        outputWav: mixedWav,
        settings: _downloadSettings,
      );

      // 7. 封装输出。
      report(VoiceSwapStage.mixing, 0.9, '封装输出视频');
      await assembler.muxVideoWithAudio(
        sourceVideo: inputVideo,
        mixedWav: mixedWav,
        outputVideo: outputVideo,
        settings: _downloadSettings,
      );

      report(VoiceSwapStage.done, 1, '换声完成');
      return VoiceSwapResult(
        outputPath: outputVideo,
        sentenceCount: sentences.length,
        durationMs: audioEndMs,
      );
    } finally {
      _cleanupWorkDir(workDir);
    }
  }

  /// 取消当前流水线（分离进程与 ffmpeg 进程）。
  void cancel() {
    separationExecutor.cancel();
    assembler.cancel();
  }

  void _cleanupWorkDir(String workDir) {
    try {
      final dir = Directory(workDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (error) {
      LogService.instance.error('清理换声临时目录失败: $error', 'voice-swap');
    }
  }

  /// 16k 单声道 16-bit wav 时长（毫秒）。
  static int _wav16kDurationMs(String path) {
    final size = File(path).lengthSync();
    // 44 字节 wav 头 + 16k * 2 字节/秒。
    final bytes = size > 44 ? size - 44 : 0;
    return (bytes / 32.0).round();
  }

  static String _defaultTempDir() =>
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'voice-swap-${DateTime.now().millisecondsSinceEpoch}';
}

class VoiceSwapPipelineException implements Exception {
  const VoiceSwapPipelineException(this.message);

  final String message;

  @override
  String toString() => message;
}
