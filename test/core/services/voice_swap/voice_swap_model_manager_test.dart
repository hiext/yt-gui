import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/voice_swap_models.dart';
import 'package:hiext_yt_gui/core/services/voice_swap/voice_swap_model_manager.dart';

VoiceSwapSettings _settings(String dir) => VoiceSwapSettings(modelDir: dir);

VoiceSwapDownloadResponse _ok(List<int> bytes, {int? contentLength}) =>
    VoiceSwapDownloadResponse(
      statusCode: 200,
      contentLength: contentLength ?? bytes.length,
      stream: Stream.value(bytes),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voice-swap-model-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('resolveFilePath', () {
    test('returns null before download', () {
      final manager = VoiceSwapModelManager(settings: _settings(tempDir.path));
      expect(manager.resolveFilePath('vad'), isNull);
      expect(manager.resolveDir('tts-kokoro'), isNull);
    });
  });

  group('ensureAvailable', () {
    test('throws a clear missing-model error when auto-download disabled', () {
      final manager = VoiceSwapModelManager(settings: _settings(tempDir.path));
      expect(
        () => manager.ensureAvailable('vad', autoDownload: false),
        throwsA(isA<VoiceSwapModelMissingException>()),
      );
    });

    test('downloads, verifies and persists a plain model', () async {
      final bytes = List<int>.generate(1024, (i) => i % 256);
      final manager = VoiceSwapModelManager(
        settings: _settings(tempDir.path),
        downloader: (_) async => _ok(bytes),
      );
      await manager.ensureAvailable('vad');
      final path = manager.resolveFilePath('vad');
      expect(path, isNotNull);
      expect(File(path!).lengthSync(), 1024);
      expect(
        File('${tempDir.path}/.checksums/vad.sha256').existsSync(),
        isTrue,
      );
      expect(await manager.isAvailable('vad'), isTrue);
    });

    test('detects tampered files via locked checksum', () async {
      final manager = VoiceSwapModelManager(
        settings: _settings(tempDir.path),
        downloader: (_) async => _ok([1, 2, 3]),
      );
      await manager.ensureAvailable('vad');
      final path = manager.resolveFilePath('vad')!;
      File(path).writeAsBytesSync([9, 9, 9]);
      expect(await manager.isAvailable('vad'), isFalse);
    });

    test('extracts archive models into the model root', () async {
      final manager = VoiceSwapModelManager(
        settings: _settings(tempDir.path),
        downloader: (_) async => _ok([0, 1, 2, 3, 4, 5]),
        extractor: (archive, root) async {
          root.createSync(recursive: true);
          File('${root.path}/model.onnx').writeAsBytesSync([1, 2, 3]);
          File('${root.path}/tokens.txt').writeAsStringSync('a\nb\n');
          Directory('${root.path}/espeak-ng-data').createSync();
        },
      );
      await manager.ensureAvailable('tts-kokoro');
      expect(await manager.isAvailable('tts-kokoro'), isTrue);
      expect(
        manager.resolveFileInDir(
          'tts-kokoro',
          candidateNames: const ['MODEL.ONNX'],
        ),
        isNotNull,
      );
      expect(
        manager.resolveDirInModel('tts-kokoro', dirName: 'ESPEAK-NG-DATA'),
        isNotNull,
      );
    });

    test('fails when the downloader returns a non-2xx status', () async {
      final manager = VoiceSwapModelManager(
        settings: _settings(tempDir.path),
        downloader: (_) async => const VoiceSwapDownloadResponse(
          statusCode: 404,
          stream: Stream.empty(),
        ),
      );
      expect(
        () => manager.ensureAvailable('vad'),
        throwsA(isA<VoiceSwapModelException>()),
      );
    });

    test('supports cancellation during download', () async {
      final controller = StreamController<List<int>>();
      final manager = VoiceSwapModelManager(
        settings: _settings(tempDir.path),
        downloader: (_) async => VoiceSwapDownloadResponse(
          statusCode: 200,
          contentLength: 100,
          stream: controller.stream,
        ),
      );
      final future = manager.ensureAvailable('vad', isCancelled: () => true);
      controller.add([1, 2, 3]);
      await controller.close();
      await expectLater(future, throwsA(isA<VoiceSwapCancelledException>()));
      expect(File('${tempDir.path}/downloads/vad').existsSync(), isFalse);
    });
  });

  group('ensureModels', () {
    test('reports per-model progress and returns all models', () async {
      final manager = VoiceSwapModelManager(
        settings: _settings(tempDir.path),
        downloader: (_) async => _ok([7, 7, 7]),
        extractor: (archive, root) async {
          root.createSync(recursive: true);
          File('${root.path}/model.onnx').writeAsBytesSync([1]);
        },
      );
      final progresses = <VoiceSwapProgress>[];
      final models = await manager.ensureModels([
        'vad',
        'tts-kokoro',
      ], onProgress: progresses.add);
      expect(models.length, 2);
      expect(progresses, isNotEmpty);
      expect(progresses.last.progress, closeTo(1.0, 0.001));
    });
  });
}
