import 'dart:convert';

/// License tier controlling feature entitlements.
enum LicenseTier { free, pro, team }

LicenseTier _tierFromName(String? name) {
  return switch (name) {
    'pro' => LicenseTier.pro,
    'team' => LicenseTier.team,
    _ => LicenseTier.free,
  };
}

/// Concrete feature limits derived from a tier. Gating points clamp user
/// settings against these values, so an unactivated app behaves as Free.
class Entitlements {
  const Entitlements({
    required this.maxConcurrentDownloads,
    required this.maxClipsPerVideo,
    required this.cloudSyncEnabled,
    required this.batchDownloadEnabled,
    required this.maxDevices,
  });

  final int maxConcurrentDownloads;
  final int maxClipsPerVideo;
  final bool cloudSyncEnabled;
  final bool batchDownloadEnabled;
  final int maxDevices;

  static const _unlimited = 1 << 30;

  factory Entitlements.forTier(LicenseTier tier) {
    return switch (tier) {
      LicenseTier.free => const Entitlements(
        maxConcurrentDownloads: 1,
        maxClipsPerVideo: 3,
        cloudSyncEnabled: false,
        batchDownloadEnabled: false,
        maxDevices: 1,
      ),
      LicenseTier.pro => const Entitlements(
        maxConcurrentDownloads: 8,
        maxClipsPerVideo: _unlimited,
        cloudSyncEnabled: false,
        batchDownloadEnabled: true,
        maxDevices: 3,
      ),
      LicenseTier.team => const Entitlements(
        maxConcurrentDownloads: 8,
        maxClipsPerVideo: _unlimited,
        cloudSyncEnabled: true,
        batchDownloadEnabled: true,
        maxDevices: 10,
      ),
    };
  }
}

/// Persisted local license state (single-row `license_state` table).
class LicenseState {
  const LicenseState({
    this.tier = LicenseTier.free,
    this.code,
    this.status,
    this.fingerprint,
    this.entitlementToken,
    this.activatedAt,
    this.lastValidatedAt,
    this.expiresAt,
    this.graceUntil,
    this.maxDevices,
  });

  final LicenseTier tier;
  final String? code;
  final String? status;
  final String? fingerprint;
  final String? entitlementToken;
  final DateTime? activatedAt;
  final DateTime? lastValidatedAt;
  final DateTime? expiresAt;
  final DateTime? graceUntil;
  final int? maxDevices;

  static const free = LicenseState();

  Entitlements get entitlements => Entitlements.forTier(effectiveTier);

  /// Tier honored right now: falls back to Free if the offline grace window
  /// has elapsed (subscription/expiry enforced without a live check).
  LicenseTier get effectiveTier {
    if (tier == LicenseTier.free) {
      return LicenseTier.free;
    }
    final now = DateTime.now();
    if (expiresAt != null && expiresAt!.isBefore(now)) {
      return LicenseTier.free;
    }
    if (graceUntil != null && graceUntil!.isBefore(now)) {
      return LicenseTier.free;
    }
    return tier;
  }

  bool get isActivated => tier != LicenseTier.free && code != null;

  LicenseState copyWith({
    LicenseTier? tier,
    String? code,
    String? status,
    String? fingerprint,
    String? entitlementToken,
    DateTime? activatedAt,
    DateTime? lastValidatedAt,
    DateTime? expiresAt,
    DateTime? graceUntil,
    int? maxDevices,
  }) {
    return LicenseState(
      tier: tier ?? this.tier,
      code: code ?? this.code,
      status: status ?? this.status,
      fingerprint: fingerprint ?? this.fingerprint,
      entitlementToken: entitlementToken ?? this.entitlementToken,
      activatedAt: activatedAt ?? this.activatedAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      graceUntil: graceUntil ?? this.graceUntil,
      maxDevices: maxDevices ?? this.maxDevices,
    );
  }

  Map<String, Object?> toJson() => {
    'tier': tier.name,
    if (code != null) 'code': code,
    if (status != null) 'status': status,
    if (fingerprint != null) 'fingerprint': fingerprint,
    if (entitlementToken != null) 'entitlementToken': entitlementToken,
    if (activatedAt != null) 'activatedAt': activatedAt!.toIso8601String(),
    if (lastValidatedAt != null)
      'lastValidatedAt': lastValidatedAt!.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (graceUntil != null) 'graceUntil': graceUntil!.toIso8601String(),
    if (maxDevices != null) 'maxDevices': maxDevices,
  };

  factory LicenseState.fromJson(Map<String, Object?> json) {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    return LicenseState(
      tier: _tierFromName(json['tier'] as String?),
      code: json['code'] as String?,
      status: json['status'] as String?,
      fingerprint: json['fingerprint'] as String?,
      entitlementToken: json['entitlementToken'] as String?,
      activatedAt: parse(json['activatedAt']),
      lastValidatedAt: parse(json['lastValidatedAt']),
      expiresAt: parse(json['expiresAt']),
      graceUntil: parse(json['graceUntil']),
      maxDevices: (json['maxDevices'] as num?)?.toInt(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory LicenseState.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?>) return LicenseState.fromJson(decoded);
    if (decoded is Map) {
      return LicenseState.fromJson(Map<String, Object?>.from(decoded));
    }
    return LicenseState.free;
  }
}

/// 当前占用授权席位的设备。
class LicenseDevice {
  const LicenseDevice({
    required this.id,
    this.deviceName,
    this.platform,
    this.activatedAt,
    this.lastSeenAt,
    this.isCurrent = false,
  });

  final String id;
  final String? deviceName;
  final String? platform;
  final DateTime? activatedAt;
  final DateTime? lastSeenAt;
  final bool isCurrent;

  factory LicenseDevice.fromJson(Map<String, Object?> json) {
    DateTime? parse(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    return LicenseDevice(
      id: json['id'] as String? ?? '',
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
      activatedAt: parse(json['activatedAt']),
      lastSeenAt: parse(json['lastSeenAt']),
      isCurrent: json['isCurrent'] == true,
    );
  }
}

/// 面向买家的授权接口返回的已激活设备席位快照。
class LicenseDevicesResult {
  const LicenseDevicesResult({
    required this.maxDevices,
    required this.activeDevices,
    required this.devices,
  });

  final int maxDevices;
  final int activeDevices;
  final List<LicenseDevice> devices;

  factory LicenseDevicesResult.fromJson(Map<String, Object?> json) {
    final rawDevices = json['devices'];
    final devices = rawDevices is List
        ? rawDevices
              .whereType<Map>()
              .map(
                (device) =>
                    LicenseDevice.fromJson(Map<String, Object?>.from(device)),
              )
              .where((device) => device.id.isNotEmpty)
              .toList(growable: false)
        : const <LicenseDevice>[];
    return LicenseDevicesResult(
      maxDevices: (json['maxDevices'] as num?)?.toInt() ?? devices.length,
      activeDevices: (json['activeDevices'] as num?)?.toInt() ?? devices.length,
      devices: devices,
    );
  }
}

/// Result returned by the license server on activate/validate.
class LicenseActivationResult {
  const LicenseActivationResult({
    required this.tier,
    required this.token,
    this.expiresAt,
    this.maxDevices,
  });

  final LicenseTier tier;
  final String token;
  final DateTime? expiresAt;
  final int? maxDevices;

  factory LicenseActivationResult.fromJson(Map<String, Object?> json) {
    return LicenseActivationResult(
      tier: _tierFromName(json['tier'] as String?),
      token: json['token'] as String? ?? '',
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      maxDevices: (json['maxDevices'] as num?)?.toInt(),
    );
  }
}
