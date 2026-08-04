import 'dart:io';

typedef ExternalProcessStarter =
    Future<void> Function(String executable, List<String> arguments);

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

Future<void> openExternalUri(
  Uri uri, {
  ExternalProcessStarter? processStarter,
  String? operatingSystem,
}) async {
  if (!const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
    throw ArgumentError.value(uri, 'uri', 'Unsupported external URI scheme');
  }
  final platform = operatingSystem ?? Platform.operatingSystem;
  final executable = switch (platform) {
    'linux' => 'xdg-open',
    'macos' => 'open',
    'windows' => 'explorer',
    _ => throw UnsupportedError('Unsupported platform: $platform'),
  };
  await (processStarter ?? _startDetached)(executable, [uri.toString()]);
}

Future<void> _startDetached(String executable, List<String> arguments) async {
  await Process.start(executable, arguments, mode: ProcessStartMode.detached);
}
