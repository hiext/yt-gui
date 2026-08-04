import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/voice_swap_models.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/source_separation_executor.dart';

VoiceSwapSettings _settings({String? binPath, String engine = 'uvr'}) =>
    VoiceSwapSettings(separationBinPath: binPath, separationEngine: engine);

void main() {
  group('bundledRelativeFiles', () {
    test('macos bundles bin plus the three dylibs', () {
      final files = SourceSeparationExecutor.bundledRelativeFiles(
        EmbeddedToolPlatform.macos,
      );
      expect(files, contains('bin/sherpa-onnx-offline-source-separation'));
      expect(
        files,
        contains('lib/libonnxruntime.1.27.0.dylib'),
      );
    });

    test('windows uses .exe and dlls', () {
      final files = SourceSeparationExecutor.bundledRelativeFiles(
        EmbeddedToolPlatform.windows,
      );
      expect(files.first, 'bin/sherpa-onnx-offline-source-separation.exe');
      expect(files, contains('lib/onnxruntime.dll'));
    });
  });

  group('resolveCli', () {
    test('custom path wins when the file exists', () async {
      final dir = Directory.systemTemp.createTempSync('sep-cli-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cli = File(
        '${dir.path}/sherpa-onnx-offline-source-separation',
      )..writeAsStringSync('');
      final executor = SourceSeparationExecutor();
      final resolved = await executor.resolveCli(
        settings: _settings(binPath: cli.path),
      );
      expect(resolved.path, cli.path);
      expect(resolved.isCustom, isTrue);
    });

    test('rejects a path that does not look like the separation cli', () async {
      final executor = SourceSeparationExecutor();
      expect(
        () => executor.resolveCli(
          settings: _settings(binPath: '/tmp/ffmpeg'),
        ),
        throwsA(isA<VoiceSwapSeparationException>()),
      );
    });

    test('falls back to PATH when no custom path is set', () async {
      final dir = Directory.systemTemp.createTempSync('sep-path-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cli = File(
        '${dir.path}/sherpa-onnx-offline-source-separation',
      )..writeAsStringSync('');
      final executor = SourceSeparationExecutor(
        platformOverride: 'macos',
        environment: {'PATH': dir.path},
      );
      final resolved = await executor.resolveCli(settings: _settings());
      expect(resolved.path, cli.path);
      expect(resolved.isCustom, isFalse);
    });

    test('throws with guidance when nothing is found', () async {
      final executor = SourceSeparationExecutor(
        platformOverride: 'macos',
        environment: const {'PATH': '/nonexistent'},
        fileExists: (_) => false,
        loadAsset: (_) async => throw StateError('no asset'),
      );
      expect(
        () => executor.resolveCli(settings: _settings()),
        throwsA(isA<VoiceSwapSeparationException>()),
      );
    });
  });

  group('separate', () {
    test('builds uvr arguments and returns the output paths', () async {
      final dir = Directory.systemTemp.createTempSync('sep-run-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final vocals = '${dir.path}/vocals.wav';
      final accomp = '${dir.path}/accompaniment.wav';

      final seen = <List<String>>[];
      final executor = SourceSeparationExecutor(
        platformOverride: 'macos',
        processRunner: (executable, arguments,
            {Map<String, String>? environment, String? workingDirectory}) async {
          seen.add(arguments);
          File(vocals).writeAsBytesSync([1]);
          File(accomp).writeAsBytesSync([2]);
          return _FakeProcess();
        },
      );
      final output = await executor.separate(
        cli: const ResolvedSeparationCli(path: '/bin/sep', isCustom: true),
        inputWav: '${dir.path}/in.wav',
        outputVocalsWav: vocals,
        outputAccompanimentWav: accomp,
        uvrModelPath: '${dir.path}/uvr.onnx',
      );
      expect(output.vocalsWav, vocals);
      expect(output.accompanimentWav, accomp);
      expect(seen.single, containsAllInOrder([
        '--uvr-model=${dir.path}/uvr.onnx',
        '--input-wav=${dir.path}/in.wav',
        '--output-vocals-wav=$vocals',
        '--output-accompaniment-wav=$accomp',
      ]));
    });

    test('fails when output files are missing after success', () async {
      final dir = Directory.systemTemp.createTempSync('sep-run-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final executor = SourceSeparationExecutor(
        platformOverride: 'macos',
        processRunner: (executable, arguments,
            {Map<String, String>? environment, String? workingDirectory}) async {
          return _FakeProcess();
        },
      );
      expect(
        () => executor.separate(
          cli: const ResolvedSeparationCli(path: '/bin/sep', isCustom: true),
          inputWav: '${dir.path}/in.wav',
          outputVocalsWav: '${dir.path}/v.wav',
          outputAccompanimentWav: '${dir.path}/a.wav',
          uvrModelPath: '${dir.path}/uvr.onnx',
        ),
        throwsA(isA<VoiceSwapSeparationException>()),
      );
    });
  });
}

class _FakeProcess implements Process {
  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  Future<int> get exitCode async => 0;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();
}
