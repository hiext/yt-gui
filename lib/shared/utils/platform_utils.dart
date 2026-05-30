import 'dart:io';

Future<void> openFolder(String path) async {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  if (Platform.isLinux) {
    await Process.start('xdg-open', [path]);
  } else if (Platform.isMacOS) {
    await Process.start('open', [path]);
  } else if (Platform.isWindows) {
    await Process.start('explorer', [path]);
  }
}
