import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/controllers/license_controller.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/device_fingerprint.dart';
import 'package:hiext_yt_gui/core/services/license_client.dart';
import 'package:hiext_yt_gui/core/services/license_purchase_link.dart';
import 'package:hiext_yt_gui/core/services/license_repository.dart';
import 'package:hiext_yt_gui/features/license/license_page.dart';
import 'package:hiext_yt_gui/l10n/app_localizations.dart';

void main() {
  Future<void> useLargeViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('configured purchase URL opens from the Pro button', (
    tester,
  ) async {
    await useLargeViewport(tester);
    final controller = LicenseController();
    addTearDown(controller.dispose);
    Uri? opened;

    await tester.pumpWidget(
      _buildApp(
        LicenseStatusPage(
          controller: controller,
          purchaseLinks: const LicensePurchaseLinkProvider(
            proUrl: 'https://buy.example.com/pro',
          ),
          uriOpener: (uri) async => opened = uri,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('license-buy-pro-button')));
    await tester.pump();

    expect(opened, Uri.parse('https://buy.example.com/pro'));
    expect(find.textContaining('已在浏览器打开购买页'), findsOneWidget);
  });

  testWidgets('missing purchase URL opens the order email fallback', (
    tester,
  ) async {
    await useLargeViewport(tester);
    final controller = LicenseController();
    addTearDown(controller.dispose);
    Uri? opened;

    await tester.pumpWidget(
      _buildApp(
        LicenseStatusPage(
          controller: controller,
          purchaseLinks: const LicensePurchaseLinkProvider(),
          uriOpener: (uri) async => opened = uri,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('license-buy-team-button')));
    await tester.pump();

    expect(opened?.scheme, 'mailto');
    expect(opened?.path, LicensePurchaseLinkProvider.fallbackEmail);
    expect(opened?.queryParameters['subject'], contains('Team'));
    expect(
      find.text(LicensePurchaseLinkProvider.fallbackEmail),
      findsOneWidget,
    );
  });

  testWidgets('mixed checkout config labels each tier destination correctly', (
    tester,
  ) async {
    await useLargeViewport(tester);
    final controller = LicenseController();
    addTearDown(controller.dispose);
    Uri? opened;

    await tester.pumpWidget(
      _buildApp(
        LicenseStatusPage(
          controller: controller,
          purchaseLinks: const LicensePurchaseLinkProvider(
            proUrl: 'https://buy.example.com/pro',
          ),
          uriOpener: (uri) async => opened = uri,
        ),
      ),
    );

    expect(find.text('购买 Pro'), findsOneWidget);
    expect(find.text('邮件购买 Team'), findsOneWidget);
    expect(find.textContaining('¥298/年'), findsOneWidget);
    expect(
      find.text(LicensePurchaseLinkProvider.fallbackEmail),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('license-buy-team-button')));
    await tester.pump();
    expect(opened?.scheme, 'mailto');
    expect(opened?.queryParameters['subject'], contains('Team'));
  });

  testWidgets(
    'active device list can release an old device after confirmation',
    (tester) async {
      await useLargeViewport(tester);
      final repository = _PageRepository(
        LicenseState(
          tier: LicenseTier.pro,
          code: 'HIEXT-TEST',
          fingerprint: 'fp-current',
          graceUntil: DateTime.now().add(const Duration(days: 5)),
        ),
      );
      final client = _PageClient();
      final controller = LicenseController(
        repository: repository,
        client: client,
        fingerprint: const _PageFingerprint(),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(
        _buildApp(LicenseStatusPage(controller: controller)),
      );
      await tester.pump();

      expect(find.text('Current PC'), findsOneWidget);
      expect(find.text('Old laptop'), findsOneWidget);
      await tester.tap(find.byKey(const Key('license-release-device-old')));
      await tester.pumpAndSettle();
      expect(find.text('释放设备席位？'), findsOneWidget);
      await tester.tap(find.text('释放').last);
      await tester.pumpAndSettle();

      expect(client.releasedDeviceId, 'device-old');
      expect(find.text('Old laptop'), findsNothing);
      expect(find.textContaining('空出的席位可用于其他设备'), findsOneWidget);

      await tester.tap(find.byKey(const Key('license-deactivate-button')));
      await tester.pumpAndSettle();
      expect(find.text('释放设备席位？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(controller.state.isActivated, isTrue);
    },
  );
}

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

class _PageRepository extends LicenseRepository {
  _PageRepository(this.state);

  LicenseState state;

  @override
  Future<LicenseState> load() async => state;

  @override
  Future<void> save(LicenseState value) async => state = value;
}

class _PageClient extends LicenseClient {
  String? releasedDeviceId;

  static const devices = [
    LicenseDevice(
      id: 'device-current',
      deviceName: 'Current PC',
      platform: 'linux',
      isCurrent: true,
    ),
    LicenseDevice(
      id: 'device-old',
      deviceName: 'Old laptop',
      platform: 'windows',
    ),
  ];

  @override
  Future<LicenseActivationResult> validate({
    required String code,
    required String fingerprint,
  }) async {
    return const LicenseActivationResult(
      tier: LicenseTier.pro,
      token: 'fresh-token',
      maxDevices: 3,
    );
  }

  @override
  Future<LicenseDevicesResult> listDevices({
    required String code,
    required String currentFingerprint,
  }) async {
    return const LicenseDevicesResult(
      maxDevices: 3,
      activeDevices: 2,
      devices: devices,
    );
  }

  @override
  Future<void> deactivateDevice({
    required String code,
    required String deviceId,
  }) async {
    releasedDeviceId = deviceId;
  }
}

class _PageFingerprint extends DeviceFingerprint {
  const _PageFingerprint();

  @override
  Future<String> compute() async => 'fp-current';
}
