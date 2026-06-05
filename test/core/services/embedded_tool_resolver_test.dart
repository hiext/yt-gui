import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_resolver.dart';

void main() {
  group('EmbeddedToolPlatformDetector', () {
    test('maps dart operating system names', () {
      expect(
        EmbeddedToolPlatformDetector.fromOperatingSystem('linux'),
        EmbeddedToolPlatform.linux,
      );
      expect(
        EmbeddedToolPlatformDetector.fromOperatingSystem('macos'),
        EmbeddedToolPlatform.macos,
      );
      expect(
        EmbeddedToolPlatformDetector.fromOperatingSystem('windows'),
        EmbeddedToolPlatform.windows,
      );
    });

    test('throws clear error for unsupported platforms', () {
      expect(
        () => EmbeddedToolPlatformDetector.fromOperatingSystem('android'),
        throwsA(isA<UnsupportedEmbeddedToolPlatformException>()),
      );
    });
  });

  group('EmbeddedToolResolver', () {
    test('resolves custom tool paths before embedded paths', () {
      final tempDir = Directory.systemTemp.createTempSync('tool-resolver-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final ytDlp = File('${tempDir.path}/yt-dlp')..writeAsStringSync('');
      final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
      );

      final bundle = resolver.resolveBundle(
        settings: DownloadSettings.defaults.copyWith(
          ytDlpPath: ytDlp.path,
          ffmpegPath: ffmpeg.path,
        ),
      );

      expect(bundle.ytDlp.path, ytDlp.path);
      expect(bundle.ffmpeg.path, ffmpeg.path);
    });

    test('throws clear error for missing custom tool path', () {
      const resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
      );

      expect(
        () => resolver.resolveBundle(
          settings: DownloadSettings.defaults.copyWith(
            ytDlpPath: '/missing/yt-dlp',
          ),
        ),
        throwsA(isA<EmbeddedToolResolutionException>()),
      );
    });

    test('resolves custom command names from PATH', () {
      final tempDir = Directory.systemTemp.createTempSync('tool-path-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final ytDlp = File('${tempDir.path}/yt-dlp')..writeAsStringSync('');
      final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': tempDir.path},
        fileExists: (path) => path == ytDlp.path || path == ffmpeg.path,
      );

      final bundle = resolver.resolveBundle(
        settings: DownloadSettings.defaults.copyWith(
          ytDlpPath: 'yt-dlp',
          ffmpegPath: 'ffmpeg',
        ),
      );

      expect(bundle.ytDlp.path, ytDlp.absolute.path);
      expect(bundle.ffmpeg.path, ffmpeg.absolute.path);
      expect(bundle.ytDlp.isCustom, isTrue);
      expect(bundle.ffmpeg.isCustom, isTrue);
    });

    test('resolves both required tools for a platform', () {
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
        environment: {'PATH': ''},
        fileExists: _noFilesExist,
      );

      final bundle = resolver.resolveBundle();

      expect(bundle.ytDlp.path, 'assets/bin/linux/yt-dlp');
      expect(bundle.ffmpeg.path, 'assets/bin/linux/ffmpeg');
    });

    test('falls back to PATH tools when embedded assets are absent', () {
      final tempDir = Directory.systemTemp.createTempSync('tool-path-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final ytDlp = File('${tempDir.path}/yt-dlp')..writeAsStringSync('');
      final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': tempDir.path},
        fileExists: (path) => path == ytDlp.path || path == ffmpeg.path,
      );

      final bundle = resolver.resolveBundle();

      expect(bundle.ytDlp.path, ytDlp.absolute.path);
      expect(bundle.ffmpeg.path, ffmpeg.absolute.path);
      expect(bundle.ytDlp.isCustom, isFalse);
      expect(bundle.ffmpeg.isCustom, isFalse);
    });

    test('checks common Homebrew path when app PATH omits it', () {
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': ''},
        fileExists: (path) =>
            path == '/opt/homebrew/bin/yt-dlp' ||
            path == '/opt/homebrew/bin/ffmpeg',
      );

      final bundle = resolver.resolveBundle();

      expect(bundle.ytDlp.path, '/opt/homebrew/bin/yt-dlp');
      expect(bundle.ffmpeg.path, '/opt/homebrew/bin/ffmpeg');
    });

    test('prefers embedded assets over PATH tools when assets exist', () {
      final tempDir = Directory.systemTemp.createTempSync('tool-path-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final ytDlp = File('${tempDir.path}/yt-dlp')..writeAsStringSync('');
      final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': tempDir.path},
        fileExists: (path) =>
            path == ytDlp.path ||
            path == ffmpeg.path ||
            path == 'assets/bin/macos/yt-dlp' ||
            path == 'assets/bin/macos/ffmpeg',
      );

      final bundle = resolver.resolveBundle();

      expect(bundle.ytDlp.path, 'assets/bin/macos/yt-dlp');
      expect(bundle.ffmpeg.path, 'assets/bin/macos/ffmpeg');
    });
  });
}

bool _noFilesExist(String path) => false;
