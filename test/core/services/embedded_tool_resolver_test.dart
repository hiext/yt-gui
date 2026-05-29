import 'package:flutter_test/flutter_test.dart';
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
    test('resolves both required tools for a platform', () {
      const resolver = EmbeddedToolResolver(
        manifest: EmbeddedToolManifest.bundled,
        platformOverride: EmbeddedToolPlatform.linux,
      );

      final bundle = resolver.resolveBundle();

      expect(bundle.ytDlp.assetPath, 'assets/bin/linux/yt-dlp');
      expect(bundle.ffmpeg.assetPath, 'assets/bin/linux/ffmpeg');
    });
  });
}
