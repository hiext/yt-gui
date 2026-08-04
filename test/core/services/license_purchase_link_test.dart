import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/license_models.dart';
import 'package:hiext_yt_gui/core/services/license_purchase_link.dart';

void main() {
  test('configured HTTPS URL is the primary purchase destination', () {
    const provider = LicensePurchaseLinkProvider(
      proUrl: 'https://buy.example.com/pro',
    );

    final destination = provider.destinationFor(
      LicenseTier.pro,
      platform: 'linux',
    );

    expect(destination.uri, Uri.parse('https://buy.example.com/pro'));
    expect(destination.isEmailFallback, isFalse);
  });
  test('Team always uses manual purchase until billing lifecycle is ready', () {
    const provider = LicensePurchaseLinkProvider(
      proUrl: 'https://buy.example.com/pro',
    );

    final destination = provider.destinationFor(LicenseTier.team);

    expect(destination.isEmailFallback, isTrue);
    expect(destination.uri.scheme, 'mailto');
  });

  test('empty configuration falls back to actionable order email', () {
    const provider = LicensePurchaseLinkProvider();

    final destination = provider.destinationFor(
      LicenseTier.team,
      platform: 'windows',
    );

    expect(destination.isEmailFallback, isTrue);
    expect(destination.uri.scheme, 'mailto');
    expect(destination.uri.path, LicensePurchaseLinkProvider.fallbackEmail);
    expect(destination.uri.queryParameters['subject'], contains('Team'));
    expect(destination.uri.queryParameters['subject'], contains('windows'));
  });

  test('HTTP or unsafe configured URL also uses email fallback', () {
    const provider = LicensePurchaseLinkProvider(
      proUrl: 'http://buy.example.com/pro',
    );

    final destination = provider.destinationFor(LicenseTier.pro);

    expect(destination.isEmailFallback, isTrue);
    expect(destination.uri.scheme, 'mailto');
    expect(provider.destinationFor(LicenseTier.team).isEmailFallback, isTrue);
  });
}
