import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/voice_swap_controller.dart';
import 'package:hiext_yt_gui/core/models/voice_swap_models.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_audio_assembler.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_model_manager.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_pipeline.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/sherpa_onnx_engine.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/source_separation_executor.dart';

/// 可编程的假流水线：只关心 run/cancel 与进度回调。
class _FakePipeline implements VoiceSwapPipeline {
  _FakePipeline({this.runImpl});

  final Future<VoiceSwapResult> Function(
    String inputVideo,
    String outputVideo,
    String presetVoiceId,
    void Function(VoiceSwapProgress progress) onProgress,
    bool Function()? isCancelled,
  )?
  runImpl;
  bool cancelled = false;

  @override
  VoiceSwapModelManager get modelManager =>
      throw UnimplementedError('controller 不访问');

  @override
  SourceSeparationExecutor get separationExecutor =>
      throw UnimplementedError('controller 不访问');

  @override
  SherpaOnnxEngine get engine => throw UnimplementedError('controller 不访问');

  @override
  VoiceSwapAudioAssembler get assembler =>
      throw UnimplementedError('controller 不访问');

  @override
  Future<VoiceSwapResult> run({
    required String inputVideo,
    required String outputVideo,
    required String presetVoiceId,
    required void Function(VoiceSwapProgress progress) onProgress,
    bool Function()? isCancelled,
  }) {
    return runImpl!(
      inputVideo,
      outputVideo,
      presetVoiceId,
      onProgress,
      isCancelled,
    );
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

const _result = VoiceSwapResult(
  outputPath: '/out/result.mp4',
  sentenceCount: 2,
  durationMs: 5000,
);

void main() {
  group('VoiceSwapController', () {
    test('成功路径：idle → 各阶段 → done 并携带结果', () async {
      final controller = VoiceSwapController(
        settingsProvider: () => VoiceSwapSettings.defaults,
        pipelineFactory: (_) => _FakePipeline(
          runImpl: (input, output, voiceId, onProgress, isCancelled) async {
            expect(input, '/in/video.mp4');
            expect(output, '/out/result.mp4');
            expect(voiceId, 'kokoro-zf-xiaobei');
            onProgress(
              const VoiceSwapProgress(
                stage: VoiceSwapStage.separating,
                progress: 0.3,
                message: '分离中',
              ),
            );
            return _result;
          },
        ),
      );

      final stages = <VoiceSwapStage>[];
      controller.addListener(() => stages.add(controller.stage));

      await controller.start(
        inputVideo: '/in/video.mp4',
        outputVideo: '/out/result.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );

      expect(controller.result, _result);
      expect(controller.error, isNull);
      expect(controller.isRunning, isFalse);
      expect(stages.first, VoiceSwapStage.downloadingModels);
      expect(stages, contains(VoiceSwapStage.separating));
      expect(stages.last, VoiceSwapStage.done);
    });

    test('运行中重复 start 被忽略', () async {
      var runCount = 0;
      final gate = Completer<VoiceSwapResult>();
      final controller = VoiceSwapController(
        pipelineFactory: (_) => _FakePipeline(
          runImpl: (a, b, c, onProgress, isCancelled) {
            runCount++;
            return gate.future;
          },
        ),
      );

      final first = controller.start(
        inputVideo: '/a.mp4',
        outputVideo: '/b.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );
      await Future<void>.delayed(Duration.zero);
      await controller.start(
        inputVideo: '/a.mp4',
        outputVideo: '/b.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );
      gate.complete(_result);
      await first;

      expect(runCount, 1);
    });

    test('取消：请求后进入 cancelled 状态', () async {
      final controller = VoiceSwapController(
        pipelineFactory: (_) => _FakePipeline(
          runImpl: (a, b, c, onProgress, isCancelled) async {
            onProgress(
              const VoiceSwapProgress(
                stage: VoiceSwapStage.transcribing,
                progress: 0.5,
              ),
            );
            while (!(isCancelled?.call() ?? false)) {
              await Future<void>.delayed(Duration.zero);
            }
            throw const VoiceSwapCancelledException();
          },
        ),
      );

      final task = controller.start(
        inputVideo: '/a.mp4',
        outputVideo: '/b.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );
      await Future<void>.delayed(Duration.zero);
      controller.cancel();
      await task;

      expect(controller.stage, VoiceSwapStage.cancelled);
      expect(controller.isRunning, isFalse);
    });

    test('取消会转发给流水线进程', () async {
      final fake = _FakePipeline(
        runImpl: (a, b, c, onProgress, isCancelled) async {
          while (!(isCancelled?.call() ?? false)) {
            await Future<void>.delayed(Duration.zero);
          }
          throw const VoiceSwapCancelledException();
        },
      );
      final controller = VoiceSwapController(pipelineFactory: (_) => fake);

      final task = controller.start(
        inputVideo: '/a.mp4',
        outputVideo: '/b.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );
      await Future<void>.delayed(Duration.zero);
      controller.cancel();
      await task;

      expect(fake.cancelled, isTrue);
    });

    test('失败：捕获异常并记录错误信息', () async {
      final controller = VoiceSwapController(
        pipelineFactory: (_) => _FakePipeline(
          runImpl: (a, b, c, onProgress, isCancelled) async {
            throw VoiceSwapPipelineException('分离失败');
          },
        ),
      );

      await controller.start(
        inputVideo: '/a.mp4',
        outputVideo: '/b.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );

      expect(controller.stage, VoiceSwapStage.failed);
      expect(controller.error, contains('分离失败'));
      expect(controller.result, isNull);
    });

    test('reset 回到 idle 并清空结果', () async {
      final controller = VoiceSwapController(
        pipelineFactory: (_) =>
            _FakePipeline(runImpl: (a, b, c, o, i) async => _result),
      );
      await controller.start(
        inputVideo: '/a.mp4',
        outputVideo: '/b.mp4',
        presetVoiceId: 'kokoro-zf-xiaobei',
      );
      controller.reset();

      expect(controller.stage, VoiceSwapStage.idle);
      expect(controller.result, isNull);
      expect(controller.error, isNull);
    });
  });
}
