@Tags(['smoke'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_resolver.dart';
import 'package:hiext_yt_gui/core/services/process_yt_dlp_executor.dart';

void main() {
  group('Smoke test with real binaries', () {
    late Directory tmpDir;
    late ProcessYtDlpExecutor executor;
    late DownloadSettings settings;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('hiext-yt-smoke-');
      const resolver = EmbeddedToolResolver(
        platformOverride: EmbeddedToolPlatform.linux,
      );
      const assetRoot = 'assets/bin/linux';
      const ytDlpPath = '$assetRoot/yt-dlp';
      const ffmpegPath = '$assetRoot/ffmpeg';
      final customSettings = DownloadSettings.defaults.copyWith(
        ytDlpPath: ytDlpPath,
        ffmpegPath: ffmpegPath,
      );

      final customTools = resolver.resolveBundle(settings: customSettings);
      expect(
        File(customTools.ytDlp.path).existsSync(),
        isTrue,
        reason: 'yt-dlp binary not found at ${customTools.ytDlp.path}',
      );
      expect(
        File(customTools.ffmpeg.path).existsSync(),
        isTrue,
        reason: 'ffmpeg binary not found at ${customTools.ffmpeg.path}',
      );

      settings = customSettings.normalized();

      executor = ProcessYtDlpExecutor(toolResolver: resolver);
    });

    tearDown(() {
      executor.dispose();
      tmpDir.deleteSync(recursive: true);
    });

    test(
      'yt-dlp --version returns version string via process',
      () async {
        final result = await Process.run('assets/bin/linux/yt-dlp', [
          '--version',
        ]);

        expect(result.exitCode, 0);
        expect(result.stdout.toString(), isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'ffmpeg -version returns version string via process',
      () async {
        final result = await Process.run('assets/bin/linux/ffmpeg', [
          '-version',
        ]);

        expect(result.exitCode, 0);
        expect(result.stdout.toString(), contains('ffmpeg version'));
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );

    test(
      'inspects URL and handles errors (real network call)',
      () async {
        try {
          final variants = await executor.inspect(
            Uri.parse('https://www.youtube.com/watch?v=NCtc5lIV7pM'),
            settings: settings,
          );

          expect(variants, isNotEmpty);
        } on YtDlpExecutorException catch (e) {
          // YouTube may block server IPs with anti-bot measures.
          // This is expected and not a code defect.
          expect(
            e.message,
            anyOf(contains('Sign in to confirm'), contains('non-zero status')),
          );
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}
