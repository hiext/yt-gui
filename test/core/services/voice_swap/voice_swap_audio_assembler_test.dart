import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_audio_assembler.dart';

void main() {
  group('buildExtractAudioArguments', () {
    test('extracts stereo 44.1k pcm without video', () {
      final args = VoiceSwapAudioAssembler.buildExtractAudioArguments(
        sourceVideo: '/in/video.mp4',
        outputWav: '/out/audio.wav',
      );
      expect(args, containsAllInOrder(['-vn', '-ac', '2', '-ar', '44100']));
      expect(args, contains('pcm_s16le'));
      expect(args.last, '/out/audio.wav');
    });
  });

  group('buildResampleArguments', () {
    test('resamples to 16k mono', () {
      final args = VoiceSwapAudioAssembler.buildResampleArguments(
        inputWav: '/in/vocals.wav',
        outputWav: '/out/vocals_16k.wav',
      );
      expect(args, containsAllInOrder(['-ac', '1', '-ar', '16000']));
    });
  });

  group('buildPlaceSentenceArguments', () {
    test('trims, fades and delays to the original time slot', () {
      final args = VoiceSwapAudioAssembler.buildPlaceSentenceArguments(
        inputWav: '/tts/tts_0.wav',
        outputWav: '/placed/placed_0.wav',
        startMs: 1500,
        maxDurationMs: 2000,
        crossfadeMs: 20,
      );
      final filter = args[args.indexOf('-af') + 1];
      expect(filter, contains('atrim=0:2.000'));
      expect(filter, contains('afade=t=in:st=0:d=0.020'));
      expect(filter, contains('afade=t=out:st=1.980:d=0.020'));
      expect(filter, contains('adelay=1500|1500'));
      expect(
        filter,
        contains('aformat=sample_rates=44100:channel_layouts=stereo'),
      );
    });

    test('fade duration shrinks to fit very short slots', () {
      final args = VoiceSwapAudioAssembler.buildPlaceSentenceArguments(
        inputWav: '/a.wav',
        outputWav: '/b.wav',
        startMs: 0,
        maxDurationMs: 10,
        crossfadeMs: 20,
      );
      final filter = args[args.indexOf('-af') + 1];
      expect(filter, contains('afade=t=in:st=0:d=0.005'));
      expect(filter, contains('afade=t=out:st=0.005:d=0.005'));
    });
  });

  group('buildMixArguments', () {
    test('mixes accompaniment with placed sentence tracks', () {
      final args = VoiceSwapAudioAssembler.buildMixArguments(
        accompanimentWav: '/mix/accompaniment.wav',
        placedWavs: ['/mix/placed_0.wav', '/mix/placed_1.wav'],
        outputWav: '/mix/mixed.wav',
      );
      expect(args.where((a) => a == '-i').length, 3);
      final filter = args[args.indexOf('-filter_complex') + 1];
      expect(
        filter,
        contains('[0:a][p1][p2]amix=inputs=3:normalize=0:duration=longest[a]'),
      );
      expect(
        filter,
        contains('[1:a]aformat=sample_rates=44100:channel_layouts=stereo[p1]'),
      );
      expect(
        filter,
        contains('[2:a]aformat=sample_rates=44100:channel_layouts=stereo[p2]'),
      );
    });

    test('mixes single sentence without sentences list', () {
      final args = VoiceSwapAudioAssembler.buildMixArguments(
        accompanimentWav: '/a.wav',
        placedWavs: const [],
        outputWav: '/m.wav',
      );
      final filter = args[args.indexOf('-filter_complex') + 1];
      expect(filter, contains('amix=inputs=1:normalize=0:duration=longest[a]'));
    });
  });

  group('buildMuxArguments', () {
    test('copies video stream and encodes mixed audio', () {
      final args = VoiceSwapAudioAssembler.buildMuxArguments(
        sourceVideo: '/in/video.mp4',
        mixedWav: '/mix/mixed.wav',
        outputVideo: '/out/result.mp4',
      );
      expect(args, containsAllInOrder(['-map', '0:v:0']));
      expect(args, containsAllInOrder(['-map', '1:a:0']));
      expect(args, containsAllInOrder(['-c:v', 'copy']));
      expect(args, containsAllInOrder(['-c:a', 'aac']));
    });
  });

  group('slot helpers', () {
    test('effectivePlacementDurationMs truncates to slot', () {
      expect(
        VoiceSwapAudioAssembler.effectivePlacementDurationMs(
          ttsDurationMs: 3000,
          slotDurationMs: 2000,
        ),
        2000,
      );
      expect(
        VoiceSwapAudioAssembler.effectivePlacementDurationMs(
          ttsDurationMs: 1000,
          slotDurationMs: 2000,
        ),
        1000,
      );
    });

    test('slotDurationMs uses next sentence start', () {
      expect(
        VoiceSwapAudioAssembler.slotDurationMs(
          startMs: 1000,
          nextStartMs: 3000,
          audioEndMs: 10000,
        ),
        2000,
      );
    });

    test('slotDurationMs falls back to audio end for the last sentence', () {
      expect(
        VoiceSwapAudioAssembler.slotDurationMs(
          startMs: 8000,
          nextStartMs: 8000,
          audioEndMs: 10000,
        ),
        2000,
      );
    });
  });

  group('writeMonoPcmWav', () {
    test('writes a valid 16-bit PCM wav file', () {
      final dir = Directory.systemTemp.createTempSync('wav-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/tts.wav';
      writeMonoPcmWav(
        path: path,
        samples: Float32List.fromList([0.0, 0.5, -0.5]),
        sampleRate: 24000,
      );
      final bytes = File(path).readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
      // 44 字节头 + 3 samples * 2 字节。
      expect(bytes.length, 44 + 6);
      final pcm = ByteData.sublistView(bytes, 44);
      expect(pcm.getInt16(0, Endian.little), 0);
      expect(pcm.getInt16(2, Endian.little), 16384);
      expect(pcm.getInt16(4, Endian.little), -16384);
    });
  });

  group('进程执行', () {
    test('大量 stderr 输出不会导致管道死锁', () async {
      final dir = Directory.systemTemp.createTempSync('vs-asm-stderr-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final script = File('${dir.path}/ffmpeg');
      script.writeAsStringSync(r'''#!/bin/sh
i=0
while [ $i -lt 2000 ]; do
  echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" >&2
  i=$((i+1))
done
exit 0
''');
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', script.path]);
      }

      final assembler = VoiceSwapAudioAssembler();
      final settings = DownloadSettings.defaults.copyWith(
        ffmpegPath: script.path,
      );
      final stopwatch = Stopwatch()..start();
      await assembler.extractAudioWav(
        sourceVideo: '${dir.path}/in.mp4',
        outputWav: '${dir.path}/out.wav',
        settings: settings,
      );
      // 假 ffmpeg 只写 stderr 并退出，若管道死锁会挂起超过 30 秒。
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 30)));
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
