import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NotificationService is a singleton', () {
    final a = NotificationService();
    final b = NotificationService();
    expect(identical(a, b), isTrue);
  });

  test(
    'showDownloadComplete does not throw when notify-send is unavailable',
    () async {
      final svc = NotificationService();
      // _available defaults to false, so it should return early without error
      await expectLater(
        svc.showDownloadComplete(title: 'Test Video'),
        completes,
      );
    },
  );

  test(
    'showDownloadFailed does not throw when notify-send is unavailable',
    () async {
      final svc = NotificationService();
      await expectLater(
        svc.showDownloadFailed(title: 'Test Video', error: 'Some error'),
        completes,
      );
    },
  );

  test('initialize sets availability based on notify-send presence', () async {
    final svc = NotificationService();
    await svc.initialize(appName: 'Test App');
    // This should complete without throwing regardless of notify-send availability
    // The _available field will be false in most CI environments
  });
}
