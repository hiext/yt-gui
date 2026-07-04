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

    test('throws clear error when custom path points to the wrong tool', () {
      final tempDir = Directory.systemTemp.createTempSync('tool-resolver-');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final ffmpeg = File('${tempDir.path}/ffmpeg')..writeAsStringSync('');
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
        fileExists: (path) => path == ffmpeg.path,
      );

      expect(
        () => resolver.resolveBundle(
          settings: DownloadSettings.defaults.copyWith(
            ytDlpPath: ffmpeg.path,
          ),
        ),
        throwsA(
          isA<EmbeddedToolResolutionException>().having(
            (error) => error.message,
            'message',
            contains('does not look like yt-dlp'),
          ),
        ),
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

    test(
      'prefers PATH tools before bundled assets when settings paths are empty',
      () {
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
        expect(bundle.ytDlp.fallbackPath, 'assets/bin/macos/yt-dlp');
        expect(bundle.ffmpeg.fallbackPath, 'assets/bin/macos/ffmpeg');
        expect(bundle.ytDlp.isCustom, isFalse);
        expect(bundle.ffmpeg.isCustom, isFalse);
      },
    );

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
      expect(bundle.ytDlp.fallbackPath, 'assets/bin/macos/yt-dlp');
      expect(bundle.ffmpeg.fallbackPath, 'assets/bin/macos/ffmpeg');
    });

    test('uses bundled assets only after settings and PATH are unavailable', () {
      final resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': ''},
        fileExists: (path) =>
            path == 'assets/bin/macos/yt-dlp' ||
            path == 'assets/bin/macos/ffmpeg',
      );

      final bundle = resolver.resolveBundle();

      expect(bundle.ytDlp.path, 'assets/bin/macos/yt-dlp');
      expect(bundle.ffmpeg.path, 'assets/bin/macos/ffmpeg');
      expect(bundle.ytDlp.fallbackPath, isNull);
      expect(bundle.ffmpeg.fallbackPath, isNull);
    });

    test('keeps bundled assets as fallback when PATH tools exist', () {
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

      expect(bundle.ytDlp.path, ytDlp.absolute.path);
      expect(bundle.ffmpeg.path, ffmpeg.absolute.path);
      expect(bundle.ytDlp.fallbackPath, 'assets/bin/macos/yt-dlp');
      expect(bundle.ffmpeg.fallbackPath, 'assets/bin/macos/ffmpeg');
    });

    test('resolves linux bundled executable from flutter assets', () {
      const expected = '/opt/hiext/data/flutter_assets/assets/bin/linux/yt-dlp';
      const resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
        environment: {'PATH': ''},
        resolvedExecutablePath: '/opt/hiext/hiext_yt_gui',
        fileExists: _linuxBundledYtDlpExists,
      );

      final tool = resolver.resolveExecutable(kind: EmbeddedToolKind.ytDlp);

      expect(tool.path, expected);
      expect(tool.isCustom, isFalse);
    });

    test('resolves macos bundled executable from App.framework assets', () {
      const expected =
          '/Applications/Hiext YT GUI.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/bin/macos/yt-dlp';
      const resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.macos,
        environment: {'PATH': ''},
        resolvedExecutablePath:
            '/Applications/Hiext YT GUI.app/Contents/MacOS/hiext_yt_gui',
        fileExists: _macosBundledYtDlpExists,
      );

      final tool = resolver.resolveExecutable(kind: EmbeddedToolKind.ytDlp);

      expect(tool.path, expected);
      expect(tool.isCustom, isFalse);
    });

    test('resolves windows bundled executable with exe suffix', () {
      const expected =
          r'C:\Program Files\Hiext YT GUI\data\flutter_assets\assets\bin\windows\yt-dlp.exe';
      const resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.windows,
        environment: {'PATH': ''},
        resolvedExecutablePath:
            r'C:\Program Files\Hiext YT GUI\hiext_yt_gui.exe',
        fileExists: _windowsBundledYtDlpExists,
      );

      final tool = resolver.resolveExecutable(kind: EmbeddedToolKind.ytDlp);

      expect(tool.path, expected);
      expect(tool.isCustom, isFalse);
    });

    test(
      'falls back to platform executable name when bundled tool is missing',
      () {
        const resolver = EmbeddedToolResolver(
          manifest: EmbeddedToolManifest.bundled,
          platformOverride: EmbeddedToolPlatform.windows,
          environment: {'PATH': ''},
          resolvedExecutablePath:
              r'C:\Program Files\Hiext YT GUI\hiext_yt_gui.exe',
          fileExists: _noFilesExist,
        );

        final tool = resolver.resolveExecutable(kind: EmbeddedToolKind.ytDlp);

        expect(tool.path, 'yt-dlp.exe');
        expect(tool.isCustom, isFalse);
      },
    );

    test('can ignore a missing custom path and use bundled executable', () {
      const expected = '/opt/hiext/data/flutter_assets/assets/bin/linux/yt-dlp';
      const resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
        environment: {'PATH': ''},
        resolvedExecutablePath: '/opt/hiext/hiext_yt_gui',
        fileExists: _linuxBundledYtDlpExists,
      );

      final tool = resolver.resolveExecutable(
        kind: EmbeddedToolKind.ytDlp,
        settings: DownloadSettings.defaults.copyWith(
          ytDlpPath: '/missing/yt-dlp',
        ),
        allowMissingCustomFallback: true,
      );

      expect(tool.path, expected);
      expect(tool.isCustom, isFalse);
    });
  });
}

bool _noFilesExist(String path) => false;

bool _linuxBundledYtDlpExists(String path) =>
    path == '/opt/hiext/data/flutter_assets/assets/bin/linux/yt-dlp';

bool _macosBundledYtDlpExists(String path) =>
    path ==
    '/Applications/Hiext YT GUI.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/bin/macos/yt-dlp';

bool _windowsBundledYtDlpExists(String path) =>
    path ==
    r'C:\Program Files\Hiext YT GUI\data\flutter_assets\assets\bin\windows\yt-dlp.exe';
