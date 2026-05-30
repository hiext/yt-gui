import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._();

  factory NotificationService() => _instance;

  NotificationService._();

  bool _available = false;

  Future<void> initialize({required String appName}) async {
    // Check if notify-send is available
    final result =
        await Process.run('which', ['notify-send'], runInShell: true);
    _available = result.exitCode == 0;
  }

  Future<void> showDownloadComplete({required String title}) async {
    if (!_available) return;
    await Process.run('notify-send', [
      '--app-name=Hiext YT GUI',
      '--icon=dialog-information',
      '下载完成',
      title,
    ]);
  }

  Future<void> showDownloadFailed({
    required String title,
    required String error,
  }) async {
    if (!_available) return;
    await Process.run('notify-send', [
      '--app-name=Hiext YT GUI',
      '--icon=dialog-error',
      '下载失败',
      '$title\n$error',
    ]);
  }
}
