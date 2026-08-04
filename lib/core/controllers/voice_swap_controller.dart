import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/voice_swap_models.dart';
import '../services/voice_swap/voice_swap_model_manager.dart';
import '../services/voice_swap/voice_swap_pipeline.dart';

/// 换声页面状态机：idle → 各流水线阶段 → done/failed/cancelled。
class VoiceSwapController extends ChangeNotifier {
  VoiceSwapController({
    required this._pipelineFactory,
    VoiceSwapSettings Function()? settingsProvider,
  }) : _settingsProvider =
           settingsProvider ?? (() => VoiceSwapSettings.defaults);

  final VoiceSwapPipeline Function(VoiceSwapSettings settings) _pipelineFactory;
  final VoiceSwapSettings Function() _settingsProvider;

  VoiceSwapStage _stage = VoiceSwapStage.idle;
  double _progress = 0;
  String? _message;
  String? _error;
  VoiceSwapResult? _result;
  VoiceSwapPipeline? _pipeline;
  bool _cancelRequested = false;

  VoiceSwapStage get stage => _stage;
  double get progress => _progress;
  String? get message => _message;
  String? get error => _error;
  VoiceSwapResult? get result => _result;
  bool get isRunning => _isRunningStage(_stage);
  bool get isBusy => _stage != VoiceSwapStage.idle;

  static bool _isRunningStage(VoiceSwapStage stage) => switch (stage) {
    VoiceSwapStage.downloadingModels ||
    VoiceSwapStage.extractingAudio ||
    VoiceSwapStage.separating ||
    VoiceSwapStage.transcribing ||
    VoiceSwapStage.synthesizing ||
    VoiceSwapStage.mixing => true,
    _ => false,
  };

  /// 开始一次换声任务。
  Future<void> start({
    required String inputVideo,
    required String outputVideo,
    required String presetVoiceId,
  }) async {
    if (isRunning) return;
    _cancelRequested = false;
    _error = null;
    _result = null;
    _progress = 0;
    _stage = VoiceSwapStage.downloadingModels;
    _message = '准备中';
    notifyListeners();

    final pipeline = _pipelineFactory(_settingsProvider());
    _pipeline = pipeline;
    try {
      final result = await pipeline.run(
        inputVideo: inputVideo,
        outputVideo: outputVideo,
        presetVoiceId: presetVoiceId,
        onProgress: (p) {
          _stage = p.stage;
          _progress = p.progress;
          _message = p.message;
          notifyListeners();
        },
        isCancelled: () => _cancelRequested,
      );
      // 终态由状态机收敛，避免依赖流水线进度回调上报 done。
      _result = result;
      _stage = VoiceSwapStage.done;
      _progress = 1;
      _message = '换声完成';
    } on VoiceSwapCancelledException {
      _stage = VoiceSwapStage.cancelled;
      _message = '已取消';
    } catch (error) {
      _stage = VoiceSwapStage.failed;
      _error = '$error';
      _message = '换声失败';
    } finally {
      _pipeline = null;
      notifyListeners();
    }
  }

  /// 请求取消；当前分离/ffmpeg 进程会被终止。
  void cancel() {
    if (!isRunning) return;
    _cancelRequested = true;
    _pipeline?.cancel();
  }

  /// 重置回初始状态（换下一个文件前调用）。
  void reset() {
    if (isRunning) return;
    _stage = VoiceSwapStage.idle;
    _progress = 0;
    _message = null;
    _error = null;
    _result = null;
    notifyListeners();
  }
}
