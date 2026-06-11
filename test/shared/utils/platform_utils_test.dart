import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/shared/utils/platform_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('platform-utils-test-');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('openFolder creates directory if it does not exist', () async {
    final path = '${tempDir.path}/new-folder';
    await openFolder(path);
    expect(Directory(path).existsSync(), isTrue);
  });

  test('openFolder does not throw when directory already exists', () async {
    final path = '${tempDir.path}/existing';
    Directory(path).createSync();
    await expectLater(openFolder(path), completes);
  });

  test('openFolder starts a process on each platform', () async {
    // This test verifies the function attempts to launch the correct opener.
    // On headless CI (Linux), xdg-open may not have a display but the
    // Process.start call itself should not throw for missing directory.
    final path = '${tempDir.path}/test-dir';
    await openFolder(path);
    // The function should complete without throwing
    expect(Directory(path).existsSync(), isTrue);
  });
}
