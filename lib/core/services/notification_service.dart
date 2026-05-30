import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();

  factory NotificationService() => _instance;

  NotificationService._();

  bool _initialized = false;

  Future<void> initialize({required String appName}) async {
    if (_initialized) return;
    await localNotifier.setup(appName: appName);
    _initialized = true;
  }

  Future<void> showDownloadComplete({required String title}) async {
    if (!_initialized) return;
    final notification = LocalNotification(
      title: '下载完成',
      body: title,
    );
    await localNotifier.notify(notification);
  }

  Future<void> showDownloadFailed({
    required String title,
    required String error,
  }) async {
    if (!_initialized) return;
    final notification = LocalNotification(
      title: '下载失败',
      body: '$title\n$error',
    );
    await localNotifier.notify(notification);
  }
}
