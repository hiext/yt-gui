import 'dart:io';

import '../../l10n/app_localizations_current.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();

  factory NotificationService() => _instance;

  NotificationService._();

  bool _available = false;

  Future<void> initialize({required String appName}) async {
    final result =
        await Process.run('which', ['notify-send'], runInShell: true);
    _available = result.exitCode == 0;
  }

  Future<void> showDownloadComplete({required String title}) async {
    if (!_available) return;
    final l10n = currentAppLocalizations();
    await Process.run('notify-send', [
      '--app-name=Hiext YT GUI',
      '--icon=dialog-information',
      l10n.downloadCompleteTitle,
      title,
    ]);
  }

  Future<void> showDownloadFailed({
    required String title,
    required String error,
  }) async {
    if (!_available) return;
    final l10n = currentAppLocalizations();
    await Process.run('notify-send', [
      '--app-name=Hiext YT GUI',
      '--icon=dialog-error',
      l10n.downloadFailedTitle,
      '$title\n$error',
    ]);
  }
}
