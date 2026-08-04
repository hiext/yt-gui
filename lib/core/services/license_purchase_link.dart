import 'dart:io';

import '../models/license_models.dart';

class LicensePurchaseDestination {
  const LicensePurchaseDestination({
    required this.uri,
    required this.isEmailFallback,
  });

  final Uri uri;
  final bool isEmailFallback;
}

/// 在不虚构支付后端的前提下解析购买入口。
///
/// 发布构建通过 `--dart-define` 提供 Pro checkout URL；配置缺失或非法时，
/// 用户仍可通过现有订单邮箱完成采购。Team 在订阅生命周期闭环前固定走人工采购。
class LicensePurchaseLinkProvider {
  const LicensePurchaseLinkProvider({
    this.proUrl = const String.fromEnvironment('HIEXT_PRO_PURCHASE_URL'),
  });

  static const fallbackEmail = 'orders@hiext.com';

  final String proUrl;

  LicensePurchaseDestination destinationFor(
    LicenseTier tier, {
    String? platform,
  }) {
    final configuredUrl = tier == LicenseTier.team ? '' : proUrl;
    final configured = Uri.tryParse(configuredUrl.trim());
    if (configured != null &&
        configured.scheme == 'https' &&
        configured.host.isNotEmpty) {
      return LicensePurchaseDestination(
        uri: configured,
        isEmailFallback: false,
      );
    }

    final tierName = tier == LicenseTier.team ? 'Team' : 'Pro';
    final platformName = platform ?? Platform.operatingSystem;
    return LicensePurchaseDestination(
      uri: Uri(
        scheme: 'mailto',
        path: fallbackEmail,
        queryParameters: {
          'subject': 'HiExt YT GUI $tierName purchase ($platformName)',
          'body':
              'I would like to purchase HiExt YT GUI $tierName.\n'
              'Platform: $platformName\n\n'
              'Please send payment instructions and an activation code.',
        },
      ),
      isEmailFallback: true,
    );
  }
}
