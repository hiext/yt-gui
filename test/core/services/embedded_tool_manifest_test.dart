import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/services/embedded_tool_manifest.dart';

void main() {
  group('EmbeddedToolManifest', () {
    test('resolves linux tool specs', () {
      const manifest = EmbeddedToolManifest.bundled;

      final ytDlp = manifest.resolve(
        platform: EmbeddedToolPlatform.linux,
        kind: EmbeddedToolKind.ytDlp,
      );
      final ffmpeg = manifest.resolve(
        platform: EmbeddedToolPlatform.linux,
        kind: EmbeddedToolKind.ffmpeg,
      );

      expect(ytDlp.executableName, 'yt-dlp');
      expect(ytDlp.assetPath, 'assets/bin/linux/yt-dlp');
      expect(ffmpeg.executableName, 'ffmpeg');
      expect(ffmpeg.assetPath, 'assets/bin/linux/ffmpeg');
    });

    test('resolves macos tool specs', () {
      const manifest = EmbeddedToolManifest.bundled;

      final ytDlp = manifest.resolve(
        platform: EmbeddedToolPlatform.macos,
        kind: EmbeddedToolKind.ytDlp,
      );
      final ffmpeg = manifest.resolve(
        platform: EmbeddedToolPlatform.macos,
        kind: EmbeddedToolKind.ffmpeg,
      );

      expect(ytDlp.executableName, 'yt-dlp');
      expect(ytDlp.assetPath, 'assets/bin/macos/yt-dlp');
      expect(ffmpeg.executableName, 'ffmpeg');
      expect(ffmpeg.assetPath, 'assets/bin/macos/ffmpeg');
    });

    test('resolves windows tool specs with exe suffix', () {
      const manifest = EmbeddedToolManifest.bundled;

      final ytDlp = manifest.resolve(
        platform: EmbeddedToolPlatform.windows,
        kind: EmbeddedToolKind.ytDlp,
      );
      final ffmpeg = manifest.resolve(
        platform: EmbeddedToolPlatform.windows,
        kind: EmbeddedToolKind.ffmpeg,
      );

      expect(ytDlp.executableName, 'yt-dlp.exe');
      expect(ytDlp.assetPath, 'assets/bin/windows/yt-dlp.exe');
      expect(ffmpeg.executableName, 'ffmpeg.exe');
      expect(ffmpeg.assetPath, 'assets/bin/windows/ffmpeg.exe');
    });

    test('throws clear error when a spec is missing', () {
      const manifest = EmbeddedToolManifest(specs: []);

      expect(
        () => manifest.resolve(
          platform: EmbeddedToolPlatform.linux,
          kind: EmbeddedToolKind.ytDlp,
        ),
        throwsA(isA<EmbeddedToolManifestException>()),
      );
    });
  });
}
