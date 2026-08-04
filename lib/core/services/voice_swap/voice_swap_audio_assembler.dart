import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/app_models.dart';
import '../embedded_tool_executable.dart';
import '../embedded_tool_manifest.dart';
import '../embedded_tool_resolver.dart';
import 'voice_swap_model_manager.dart';

/// 音频组装器：ffmpeg 提取音轨 / 分句放置 / 混音 / 封装。
///
/// 所有命令构造均为纯函数（可单测）；执行依赖仓库 ffmpeg 解析规则。
class VoiceSwapAudioAssembler {
  VoiceSwapAudioAssembler({
    EmbeddedToolResolver? toolResolver,
    Future<ByteData> Function(String path)? loadAsset,
  }) : _toolResolver = toolResolver ?? const EmbeddedToolResolver(),
       _loadAsset = loadAsset ?? rootBundle.load;

  final EmbeddedToolResolver _toolResolver;
  final Future<ByteData> Function(String path) _loadAsset;
  final Set<Process> _activeProcesses = {};

  /// 交叉淡化时长（毫秒），避免句首尾爆音。
  static const crossfadeMs = 20;

  /// 解析 ffmpeg 路径（设置路径 > PATH > 内置）。
  Future<String> _resolveFfmpeg(DownloadSettings settings) async {
    final tool = _toolResolver.resolveExecutable(
      kind: EmbeddedToolKind.ffmpeg,
      settings: settings,
    );
    final resolver = EmbeddedToolExecutableResolver(loadAsset: _loadAsset);
    return resolver.ensureExecutable(tool);
  }

  /// 从视频提取 44.1kHz 立体声 wav（分离模型输入标准）。
  Future<String> extractAudioWav({
    required String sourceVideo,
    required String outputWav,
    required DownloadSettings settings,
  }) async {
    final ffmpeg = await _resolveFfmpeg(settings);
    await _run(
      ffmpeg,
      buildExtractAudioArguments(
        sourceVideo: sourceVideo,
        outputWav: outputWav,
      ),
      '提取音轨',
    );
    return outputWav;
  }

  /// 重采样为 16kHz 单声道（ASR/VAD 输入标准）。
  Future<String> resampleTo16kMono({
    required String inputWav,
    required String outputWav,
    required DownloadSettings settings,
  }) async {
    final ffmpeg = await _resolveFfmpeg(settings);
    await _run(
      ffmpeg,
      buildResampleArguments(inputWav: inputWav, outputWav: outputWav),
      '重采样',
    );
    return outputWav;
  }

  /// 逐句生成「已放置」的 wav（adelay 定位 + 淡入淡出 + 截断）。
  Future<void> placeSentences({
    required List<String> ttsWavs,
    required List<int> startMsList,
    required List<int> slotMsList,
    required String outputDir,
    required DownloadSettings settings,
    bool Function()? isCancelled,
  }) async {
    final ffmpeg = await _resolveFfmpeg(settings);
    for (var i = 0; i < ttsWavs.length; i++) {
      if (isCancelled?.call() ?? false) {
        throw VoiceSwapCancelledException();
      }
      final output = '$outputDir${Platform.pathSeparator}placed_$i.wav';
      await _run(
        ffmpeg,
        buildPlaceSentenceArguments(
          inputWav: ttsWavs[i],
          outputWav: output,
          startMs: startMsList[i],
          maxDurationMs: slotMsList[i],
          crossfadeMs: crossfadeMs,
        ),
        '放置第 ${i + 1} 句',
      );
    }
  }

  /// 伴奏 + 全部已放置句轨混音。
  Future<String> mixSentencesWithAccompaniment({
    required String accompanimentWav,
    required List<String> placedWavs,
    required String outputWav,
    required DownloadSettings settings,
  }) async {
    final ffmpeg = await _resolveFfmpeg(settings);
    await _run(
      ffmpeg,
      buildMixArguments(
        accompanimentWav: accompanimentWav,
        placedWavs: placedWavs,
        outputWav: outputWav,
      ),
      '混音',
    );
    return outputWav;
  }

  /// 视频画面 + 新混音轨封装输出（视频流 copy）。
  Future<String> muxVideoWithAudio({
    required String sourceVideo,
    required String mixedWav,
    required String outputVideo,
    required DownloadSettings settings,
  }) async {
    final ffmpeg = await _resolveFfmpeg(settings);
    await _run(
      ffmpeg,
      buildMuxArguments(
        sourceVideo: sourceVideo,
        mixedWav: mixedWav,
        outputVideo: outputVideo,
      ),
      '封装输出',
    );
    return outputVideo;
  }

  Future<void> _run(String ffmpeg, List<String> args, String label) async {
    final process = await Process.start(ffmpeg, args);
    _activeProcesses.add(process);
    try {
      // 先显式订阅并消费 stderr，避免管道写满导致进程阻塞、永不退出。
      // 注意 Stream.join() 是惰性的，必须 listen 才会开始消费。
      final stderrBuffer = StringBuffer();
      unawaited(process.stdout.drain<void>());
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .listen(stderrBuffer.write)
          .asFuture<void>();
      final exitCode = await process.exitCode;
      final stderr = stderrBuffer.toString();
      await stderrDone;
      if (exitCode != 0) {
        throw VoiceSwapAudioException(
          '$label失败（退出码 $exitCode）：${_tail(stderr)}',
        );
      }
    } finally {
      _activeProcesses.remove(process);
    }
  }

  /// 取消所有进行中的 ffmpeg。
  void cancel() {
    for (final process in _activeProcesses) {
      process.kill(ProcessSignal.sigterm);
    }
    _activeProcesses.clear();
  }

  static String _tail(String text, [int maxLines = 8]) {
    final lines = text.trim().split('\n');
    if (lines.length <= maxLines) return text.trim();
    return lines.sublist(lines.length - maxLines).join('\n');
  }

  // ---- 纯命令构造（单测覆盖） ----

  static List<String> buildExtractAudioArguments({
    required String sourceVideo,
    required String outputWav,
  }) => [
    '-y',
    '-i',
    sourceVideo,
    '-vn',
    '-ac',
    '2',
    '-ar',
    '44100',
    '-c:a',
    'pcm_s16le',
    outputWav,
  ];

  static List<String> buildResampleArguments({
    required String inputWav,
    required String outputWav,
  }) => [
    '-y',
    '-i',
    inputWav,
    '-ac',
    '1',
    '-ar',
    '16000',
    '-c:a',
    'pcm_s16le',
    outputWav,
  ];

  /// 单句放置：先按槽位截断，再淡入淡出，最后 adelay 到原句起点。
  static List<String> buildPlaceSentenceArguments({
    required String inputWav,
    required String outputWav,
    required int startMs,
    required int maxDurationMs,
    int crossfadeMs = VoiceSwapAudioAssembler.crossfadeMs,
  }) {
    final maxDurSec = maxDurationMs / 1000.0;
    final fadeSec = (crossfadeMs / 1000.0).clamp(0.0, maxDurSec / 2);
    final fadeOutStart = (maxDurSec - fadeSec).clamp(0.0, maxDurSec);
    final filters = <String>[
      'atrim=0:${_seconds(maxDurationMs)}',
      'afade=t=in:st=0:d=${fadeSec.toStringAsFixed(3)}',
      'afade=t=out:st=${fadeOutStart.toStringAsFixed(3)}:d=${fadeSec.toStringAsFixed(3)}',
      'adelay=$startMs|$startMs',
      'aformat=sample_rates=44100:channel_layouts=stereo',
    ];
    return [
      '-y',
      '-i',
      inputWav,
      '-af',
      filters.join(','),
      '-c:a',
      'pcm_s16le',
      outputWav,
    ];
  }

  static List<String> buildMixArguments({
    required String accompanimentWav,
    required List<String> placedWavs,
    required String outputWav,
  }) {
    final inputs = <String>['-y', '-i', accompanimentWav];
    for (final placed in placedWavs) {
      inputs.addAll(['-i', placed]);
    }
    final filterParts = <String>[];
    for (var i = 1; i <= placedWavs.length; i++) {
      filterParts.add(
        '[$i:a]aformat=sample_rates=44100:channel_layouts=stereo[p$i]',
      );
    }
    final mixInputs = [
      '[0:a]',
      for (var i = 1; i <= placedWavs.length; i++) '[p$i]',
    ].join();
    filterParts.add(
      '$mixInputs amix=inputs=${placedWavs.length + 1}:'
              'normalize=0:duration=longest[a]'
          .replaceAll(' amix=', 'amix='),
    );
    return [
      ...inputs,
      '-filter_complex',
      filterParts.join(';'),
      '-map',
      '[a]',
      '-ar',
      '44100',
      '-c:a',
      'pcm_s16le',
      outputWav,
    ];
  }

  static List<String> buildMuxArguments({
    required String sourceVideo,
    required String mixedWav,
    required String outputVideo,
  }) => [
    '-y',
    '-i',
    sourceVideo,
    '-i',
    mixedWav,
    '-map',
    '0:v:0',
    '-map',
    '1:a:0',
    '-c:v',
    'copy',
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-shortest',
    '-movflags',
    '+faststart',
    outputVideo,
  ];

  /// 有效放置时长：TTS 句长超过槽位则截断到槽位。
  static int effectivePlacementDurationMs({
    required int ttsDurationMs,
    required int slotDurationMs,
  }) => ttsDurationMs < slotDurationMs ? ttsDurationMs : slotDurationMs;

  /// 槽位：本句起点到下一句起点；最后一句取到音频末尾（由调用方传入）。
  static int slotDurationMs({
    required int startMs,
    required int nextStartMs,
    required int audioEndMs,
  }) {
    final end = nextStartMs > startMs ? nextStartMs : audioEndMs;
    final slot = end - startMs;
    return slot > 0 ? slot : 1000;
  }

  static String _seconds(int ms) => (ms / 1000).toStringAsFixed(3);
}

/// 纯 Dart WAV 写入（16-bit PCM 单声道），供 TTS 句文件落盘。
void writeMonoPcmWav({
  required String path,
  required Float32List samples,
  required int sampleRate,
}) {
  final bytes = BytesBuilder();
  void writeString(String s) => bytes.add(s.codeUnits);
  void writeUint32(int v) {
    bytes.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
  }

  void writeUint16(int v) {
    bytes.add([v & 0xff, (v >> 8) & 0xff]);
  }

  final dataSize = samples.length * 2;
  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1);
  writeUint16(1);
  writeUint32(sampleRate);
  writeUint32(sampleRate * 2);
  writeUint16(2);
  writeUint16(16);
  writeString('data');
  writeUint32(dataSize);
  final pcm = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 32767).round().clamp(-32768, 32767).toInt();
    pcm.setInt16(i * 2, v, Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());
  File(path).parent.createSync(recursive: true);
  File(path).writeAsBytesSync(bytes.toBytes());
}

class VoiceSwapAudioException implements Exception {
  const VoiceSwapAudioException(this.message);

  final String message;

  @override
  String toString() => message;
}
