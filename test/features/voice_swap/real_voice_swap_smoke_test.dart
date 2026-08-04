import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/models/voice_swap_models.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/sherpa_onnx_engine.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/source_separation_executor.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_audio_assembler.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_model_manager.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_pipeline.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// 换声真实端到端冒烟（依赖环境变量，缺省时跳过）：
///   VS_SMOKE_MODEL_DIR  已下载的模型目录（uvr/vad/asr-sensevoice/tts-kokoro）
///   VS_SMOKE_VIDEO      输入视频（含人声+背景音乐）
///   VS_SMOKE_OUT        输出目录
///   VS_SMOKE_FFMPEG     ffmpeg 可执行文件路径
///   VS_SMOKE_DYLIB_DIR  sherpa-onnx 动态库目录（可选，默认用内置 sherpa-sep/lib）
void main() {
  // test() 不自动初始化 binding，rootBundle 需要显式初始化。
  TestWidgetsFlutterBinding.ensureInitialized();

  final modelDir = Platform.environment['VS_SMOKE_MODEL_DIR'];
  final inputVideo = Platform.environment['VS_SMOKE_VIDEO'];
  final outDir = Platform.environment['VS_SMOKE_OUT'];
  final ffmpegPath = Platform.environment['VS_SMOKE_FFMPEG'];

  test('真实模型端到端：分离 → 识别 → 合成 → 混音 → 封装', () async {
    if (modelDir == null ||
        inputVideo == null ||
        outDir == null ||
        ffmpegPath == null) {
      markTestSkipped('缺少冒烟环境变量，跳过真实模型冒烟');
      return;
    }
    expect(File(inputVideo).existsSync(), isTrue, reason: '输入视频不存在');
    expect(Directory(modelDir).existsSync(), isTrue, reason: '模型目录不存在');

    Directory(outDir).createSync(recursive: true);
    final outputVideo = '$outDir${Platform.pathSeparator}result.mp4';

    final voiceSwapSettings = VoiceSwapSettings(modelDir: modelDir);
    final downloadSettings = DownloadSettings.defaults.copyWith(
      ffmpegPath: ffmpegPath,
    );
    final manager = VoiceSwapModelManager(settings: voiceSwapSettings);
    final executor = SourceSeparationExecutor();
    final engine = SherpaOnnxEngine(
      initializeBindings: () async {
        final dylibDir =
            Platform.environment['VS_SMOKE_DYLIB_DIR'] ??
            '${Directory.current.path}${Platform.pathSeparator}'
                'assets${Platform.pathSeparator}bin${Platform.pathSeparator}'
                'macos${Platform.pathSeparator}sherpa-sep${Platform.pathSeparator}lib';
        sherpa_onnx.initBindings(dylibDir);
      },
    );
    final pipeline = VoiceSwapPipeline(
      modelManager: manager,
      separationExecutor: executor,
      engine: engine,
      assembler: VoiceSwapAudioAssembler(),
      downloadSettings: downloadSettings,
      voiceSwapSettings: voiceSwapSettings,
    );

    final stopwatch = Stopwatch()..start();
    final stages = <String>[];
    final result = await pipeline.run(
      inputVideo: inputVideo,
      outputVideo: outputVideo,
      presetVoiceId: 'kokoro-zf-xiaobei',
      onProgress: (p) {
        if (stages.isEmpty || stages.last != p.stage.name) {
          stages.add(p.stage.name);
          debugPrint(
            '[vs-smoke] stage=${p.stage.name} '
            'progress=${(p.progress * 100).toStringAsFixed(0)}% '
            'msg=${p.message}',
          );
        }
      },
    );
    stopwatch.stop();

    expect(File(outputVideo).existsSync(), isTrue, reason: '未生成输出视频');
    expect(File(outputVideo).lengthSync(), greaterThan(10000));
    expect(result.sentenceCount, greaterThan(0), reason: '未识别到任何句子');
    expect(result.durationMs, greaterThan(0));
    expect(stages.last, 'done');
    debugPrint(
      '[vs-smoke] 完成：句子数=${result.sentenceCount} '
      '时长=${result.durationMs}ms 耗时=${stopwatch.elapsed.inSeconds}s '
      '输出=$outputVideo',
    );
  }, timeout: const Timeout(Duration(minutes: 15)));
}
