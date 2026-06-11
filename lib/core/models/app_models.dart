import 'dart:convert';
import 'dart:io';

enum DownloadMode { serial, queue, concurrent }

enum LogLevel { debug, info, warning, error }

enum AiAnalysisProvider { builtIn, externalCommand, cloudEndpoint }

enum BuiltInClipAnalyzerMode { balanced, visualFocused, audioFocused }

enum ClipRecordStatus { pending, cutting, completed, failed }

enum AiCloudVendor {
  custom,
  openAI,
  gemini,
  anthropic,
  groq,
  deepSeek,
  qwen,
  openRouter,
}

class AiCloudConfig {
  const AiCloudConfig({
    required this.id,
    required this.vendor,
    required this.name,
    required this.endpoint,
    required this.model,
    this.apiKey,
    this.enabled = true,
  });

  final String id;
  final AiCloudVendor vendor;
  final String name;
  final String endpoint;
  final String model;
  final String? apiKey;
  final bool enabled;

  static AiCloudConfig preset(AiCloudVendor vendor, {String? id}) {
    final presetId = id ?? vendor.name;
    switch (vendor) {
      case AiCloudVendor.openAI:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'OpenAI',
          endpoint: 'https://api.openai.com/v1/chat/completions',
          model: 'gpt-4o-mini',
        );
      case AiCloudVendor.gemini:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'Google Gemini',
          endpoint:
              'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent',
          model: 'gemini-2.0-flash',
        );
      case AiCloudVendor.anthropic:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'Anthropic Claude',
          endpoint: 'https://api.anthropic.com/v1/messages',
          model: 'claude-3-5-haiku-latest',
        );
      case AiCloudVendor.groq:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'Groq',
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          model: 'llama-3.1-8b-instant',
        );
      case AiCloudVendor.deepSeek:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'DeepSeek',
          endpoint: 'https://api.deepseek.com/chat/completions',
          model: 'deepseek-chat',
        );
      case AiCloudVendor.qwen:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'Qwen / DashScope',
          endpoint:
              'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
          model: 'qwen-plus',
        );
      case AiCloudVendor.openRouter:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'OpenRouter',
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          model: 'openai/gpt-4o-mini',
        );
      case AiCloudVendor.custom:
        return AiCloudConfig(
          id: presetId,
          vendor: vendor,
          name: 'Custom JSON endpoint',
          endpoint: '',
          model: '',
        );
    }
  }

  AiCloudConfig copyWith({
    String? id,
    AiCloudVendor? vendor,
    String? name,
    String? endpoint,
    String? model,
    Object? apiKey = _unchanged,
    bool? enabled,
  }) {
    return AiCloudConfig(
      id: id ?? this.id,
      vendor: vendor ?? this.vendor,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey == _unchanged ? this.apiKey : apiKey as String?,
      enabled: enabled ?? this.enabled,
    ).normalized();
  }

  AiCloudConfig normalized() {
    return AiCloudConfig(
      id: id.trim().isEmpty ? vendor.name : id.trim(),
      vendor: vendor,
      name: name.trim().isEmpty ? preset(vendor).name : name.trim(),
      endpoint: endpoint.trim(),
      model: model.trim(),
      apiKey: _normalizeOptional(apiKey),
      enabled: enabled,
    );
  }

  bool get hasEndpoint => endpoint.trim().isNotEmpty;

  Map<String, Object> toJson() {
    final map = <String, Object>{
      'id': id,
      'vendor': vendor.name,
      'name': name,
      'endpoint': endpoint,
      'model': model,
      'enabled': enabled,
    };
    if (apiKey != null) {
      map['apiKey'] = apiKey!;
    }
    return map;
  }

  factory AiCloudConfig.fromJson(Map<String, Object?> json) {
    return AiCloudConfig(
      id: json['id'] as String? ?? '',
      vendor: _parseVendor(json['vendor']),
      name: json['name'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      model: json['model'] as String? ?? '',
      apiKey: json['apiKey'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    ).normalized();
  }

  static AiCloudVendor _parseVendor(Object? value) {
    if (value is String) {
      final normalized = value.replaceAll('_', '').toLowerCase();
      return AiCloudVendor.values.firstWhere(
        (vendor) => vendor.name.toLowerCase() == normalized,
        orElse: () {
          if (normalized == 'openai') return AiCloudVendor.openAI;
          if (normalized == 'deepseek') return AiCloudVendor.deepSeek;
          if (normalized == 'openrouter') return AiCloudVendor.openRouter;
          return AiCloudVendor.custom;
        },
      );
    }
    return AiCloudVendor.custom;
  }

  static String? _normalizeOptional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

enum DownloadStatus {
  idle,
  parsing,
  ready,
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class DownloadSettings {
  const DownloadSettings({
    required this.saveDirectory,
    required this.downloadMode,
    required this.concurrentCount,
    required this.defaultQuality,
    required this.downloadSubtitles,
    required this.downloadThumbnail,
    required this.disclaimerAccepted,
    this.logLevel = LogLevel.debug,
    this.recommendedVariantCount = 2,
    this.aiAnalysisProvider = AiAnalysisProvider.builtIn,
    this.builtInClipAnalyzerMode = BuiltInClipAnalyzerMode.balanced,
    this.ytDlpPath,
    this.ffmpegPath,
    this.aiAnalyzerCommand,
    this.aiCloudEndpoint,
    this.aiCloudApiKey,
    this.aiCloudModel,
    this.selectedAiCloudConfigId,
    this.aiCloudConfigs = const [],
    this.cookieConfigs = const [],
    this.defaultCookieBrowser,
    this.autoClipConfig = AutoClipConfig.defaults,
  });

  static const defaults = DownloadSettings(
    saveDirectory: '',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    recommendedVariantCount: 2,
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
    logLevel: LogLevel.debug,
  );

  static String defaultSaveDirectory() {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    if (Platform.isMacOS) return '$home/Movies';
    return '$home/Videos';
  }

  final String saveDirectory;
  final DownloadMode downloadMode;
  final int concurrentCount;
  final String defaultQuality;
  final int recommendedVariantCount;
  final bool downloadSubtitles;
  final bool downloadThumbnail;
  final bool disclaimerAccepted;
  final LogLevel logLevel;
  final AiAnalysisProvider aiAnalysisProvider;
  final BuiltInClipAnalyzerMode builtInClipAnalyzerMode;
  final String? ytDlpPath;
  final String? ffmpegPath;
  final String? aiAnalyzerCommand;
  final String? aiCloudEndpoint;
  final String? aiCloudApiKey;
  final String? aiCloudModel;
  final String? selectedAiCloudConfigId;
  final List<AiCloudConfig> aiCloudConfigs;
  final List<CookieConfig> cookieConfigs;
  final String? defaultCookieBrowser;
  final AutoClipConfig autoClipConfig;

  AiCloudConfig? get selectedAiCloudConfig {
    AiCloudConfig? fallback;
    for (final config in aiCloudConfigs) {
      if (!config.enabled) continue;
      fallback ??= config;
      if (config.id == selectedAiCloudConfigId) {
        return config;
      }
    }
    if (fallback != null) return fallback;
    if (aiCloudEndpoint == null &&
        aiCloudModel == null &&
        aiCloudApiKey == null) {
      return null;
    }
    return AiCloudConfig(
      id: selectedAiCloudConfigId ?? 'legacy-cloud',
      vendor: AiCloudVendor.custom,
      name: 'Legacy cloud endpoint',
      endpoint: aiCloudEndpoint ?? '',
      model: aiCloudModel ?? '',
      apiKey: aiCloudApiKey,
    ).normalized();
  }

  DownloadSettings copyWith({
    String? saveDirectory,
    DownloadMode? downloadMode,
    int? concurrentCount,
    String? defaultQuality,
    int? recommendedVariantCount,
    bool? downloadSubtitles,
    bool? downloadThumbnail,
    bool? disclaimerAccepted,
    LogLevel? logLevel,
    AiAnalysisProvider? aiAnalysisProvider,
    BuiltInClipAnalyzerMode? builtInClipAnalyzerMode,
    Object? ytDlpPath = _unchanged,
    Object? ffmpegPath = _unchanged,
    Object? aiAnalyzerCommand = _unchanged,
    Object? aiCloudEndpoint = _unchanged,
    Object? aiCloudApiKey = _unchanged,
    Object? aiCloudModel = _unchanged,
    Object? selectedAiCloudConfigId = _unchanged,
    Object? aiCloudConfigs = _unchanged,
    Object? cookieConfigs = _unchanged,
    Object? defaultCookieBrowser = _unchanged,
    AutoClipConfig? autoClipConfig,
  }) {
    return DownloadSettings(
      saveDirectory: saveDirectory ?? this.saveDirectory,
      downloadMode: downloadMode ?? this.downloadMode,
      concurrentCount: concurrentCount ?? this.concurrentCount,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      recommendedVariantCount:
          recommendedVariantCount ?? this.recommendedVariantCount,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      downloadThumbnail: downloadThumbnail ?? this.downloadThumbnail,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
      logLevel: logLevel ?? this.logLevel,
      aiAnalysisProvider: aiAnalysisProvider ?? this.aiAnalysisProvider,
      builtInClipAnalyzerMode:
          builtInClipAnalyzerMode ?? this.builtInClipAnalyzerMode,
      ytDlpPath: ytDlpPath == _unchanged
          ? this.ytDlpPath
          : ytDlpPath as String?,
      ffmpegPath: ffmpegPath == _unchanged
          ? this.ffmpegPath
          : ffmpegPath as String?,
      aiAnalyzerCommand: aiAnalyzerCommand == _unchanged
          ? this.aiAnalyzerCommand
          : aiAnalyzerCommand as String?,
      aiCloudEndpoint: aiCloudEndpoint == _unchanged
          ? this.aiCloudEndpoint
          : aiCloudEndpoint as String?,
      aiCloudApiKey: aiCloudApiKey == _unchanged
          ? this.aiCloudApiKey
          : aiCloudApiKey as String?,
      aiCloudModel: aiCloudModel == _unchanged
          ? this.aiCloudModel
          : aiCloudModel as String?,
      selectedAiCloudConfigId: selectedAiCloudConfigId == _unchanged
          ? this.selectedAiCloudConfigId
          : selectedAiCloudConfigId as String?,
      aiCloudConfigs: aiCloudConfigs == _unchanged
          ? this.aiCloudConfigs
          : aiCloudConfigs as List<AiCloudConfig>,
      cookieConfigs: cookieConfigs == _unchanged
          ? this.cookieConfigs
          : cookieConfigs as List<CookieConfig>,
      defaultCookieBrowser: defaultCookieBrowser == _unchanged
          ? this.defaultCookieBrowser
          : defaultCookieBrowser as String?,
      autoClipConfig: autoClipConfig ?? this.autoClipConfig,
    ).normalized();
  }

  DownloadSettings normalized() {
    final normalizedSaveDirectory = saveDirectory.trim().isEmpty
        ? defaultSaveDirectory()
        : saveDirectory.trim();
    final normalizedDefaultQuality = defaultQuality.trim().isEmpty
        ? defaults.defaultQuality
        : defaultQuality.trim();
    final normalizedYtDlpPath = _normalizeOptionalPath(ytDlpPath);
    final normalizedFfmpegPath = _normalizeOptionalPath(ffmpegPath);
    final normalizedAiAnalyzerCommand = _normalizeOptionalPath(
      aiAnalyzerCommand,
    );
    final normalizedAiCloudEndpoint = _normalizeOptionalPath(aiCloudEndpoint);
    final normalizedAiCloudApiKey = _normalizeOptionalPath(aiCloudApiKey);
    final normalizedAiCloudModel = _normalizeOptionalPath(aiCloudModel);
    final normalizedAiCloudConfigs = _normalizeAiCloudConfigs(
      aiCloudConfigs,
      legacyEndpoint: normalizedAiCloudEndpoint,
      legacyApiKey: normalizedAiCloudApiKey,
      legacyModel: normalizedAiCloudModel,
    );
    final normalizedSelectedAiCloudConfigId = _selectedAiCloudConfigId(
      selectedAiCloudConfigId,
      normalizedAiCloudConfigs,
    );
    final selectedAiCloudConfig = _findAiCloudConfig(
      normalizedSelectedAiCloudConfigId,
      normalizedAiCloudConfigs,
    );

    return DownloadSettings(
      saveDirectory: normalizedSaveDirectory,
      downloadMode: downloadMode,
      concurrentCount: concurrentCount.clamp(1, 8).toInt(),
      defaultQuality: normalizedDefaultQuality,
      recommendedVariantCount: recommendedVariantCount.clamp(1, 5).toInt(),
      downloadSubtitles: downloadSubtitles,
      downloadThumbnail: downloadThumbnail,
      disclaimerAccepted: disclaimerAccepted,
      aiAnalysisProvider: aiAnalysisProvider,
      builtInClipAnalyzerMode: builtInClipAnalyzerMode,
      ytDlpPath: normalizedYtDlpPath,
      ffmpegPath: normalizedFfmpegPath,
      aiAnalyzerCommand: normalizedAiAnalyzerCommand,
      aiCloudEndpoint:
          selectedAiCloudConfig?.endpoint ?? normalizedAiCloudEndpoint,
      aiCloudApiKey: selectedAiCloudConfig?.apiKey ?? normalizedAiCloudApiKey,
      aiCloudModel: selectedAiCloudConfig?.model ?? normalizedAiCloudModel,
      selectedAiCloudConfigId: normalizedSelectedAiCloudConfigId,
      aiCloudConfigs: normalizedAiCloudConfigs,
      cookieConfigs: cookieConfigs,
      defaultCookieBrowser: defaultCookieBrowser,
      autoClipConfig: autoClipConfig,
    );
  }

  String? _normalizeOptionalPath(String? path) {
    final trimmed = path?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Map<String, Object> toJson() {
    final map = <String, Object>{
      'saveDirectory': saveDirectory,
      'downloadMode': downloadMode.name,
      'concurrentCount': concurrentCount,
      'defaultQuality': defaultQuality,
      'recommendedVariantCount': recommendedVariantCount,
      'downloadSubtitles': downloadSubtitles,
      'downloadThumbnail': downloadThumbnail,
      'disclaimerAccepted': disclaimerAccepted,
      'logLevel': logLevel.name,
      'aiAnalysisProvider': aiAnalysisProvider.name,
      'builtInClipAnalyzerMode': builtInClipAnalyzerMode.name,
    };
    if (ytDlpPath != null) map['ytDlpPath'] = ytDlpPath!;
    if (ffmpegPath != null) map['ffmpegPath'] = ffmpegPath!;
    if (aiAnalyzerCommand != null) {
      map['aiAnalyzerCommand'] = aiAnalyzerCommand!;
    }
    if (aiCloudEndpoint != null) {
      map['aiCloudEndpoint'] = aiCloudEndpoint!;
    }
    if (aiCloudApiKey != null) {
      map['aiCloudApiKey'] = aiCloudApiKey!;
    }
    if (aiCloudModel != null) {
      map['aiCloudModel'] = aiCloudModel!;
    }
    if (selectedAiCloudConfigId != null) {
      map['selectedAiCloudConfigId'] = selectedAiCloudConfigId!;
    }
    if (aiCloudConfigs.isNotEmpty) {
      map['aiCloudConfigs'] = aiCloudConfigs
          .map((config) => config.toJson())
          .toList();
    }
    if (defaultCookieBrowser != null) {
      map['defaultCookieBrowser'] = defaultCookieBrowser!;
    }
    map['autoClipConfig'] = autoClipConfig.toJson();
    return map;
  }

  factory DownloadSettings.fromJson(Map<String, Object?> json) {
    int? parseCount(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    bool? parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v == 'true' || v == '1';
      return null;
    }

    final aiAnalyzerCommand = json['aiAnalyzerCommand'] as String?;
    final aiCloudEndpoint = json['aiCloudEndpoint'] as String?;
    final hasLegacyCloudConfig =
        _normalizeStaticOptionalPath(aiCloudEndpoint) != null ||
        _normalizeStaticOptionalPath(json['aiCloudApiKey'] as String?) !=
            null ||
        _normalizeStaticOptionalPath(json['aiCloudModel'] as String?) != null;
    final rawAiCloudConfigs = _decodeJsonList(json['aiCloudConfigs']);
    final aiCloudConfigs = rawAiCloudConfigs is List
        ? rawAiCloudConfigs
              .whereType<Map>()
              .map(
                (value) =>
                    AiCloudConfig.fromJson(Map<String, Object?>.from(value)),
              )
              .toList()
        : const <AiCloudConfig>[];
    final aiAnalysisProvider = json.containsKey('aiAnalysisProvider')
        ? _parseAiAnalysisProvider(json['aiAnalysisProvider'])
        : _normalizeStaticOptionalPath(aiAnalyzerCommand) == null
        ? hasLegacyCloudConfig
              ? AiAnalysisProvider.cloudEndpoint
              : defaults.aiAnalysisProvider
        : AiAnalysisProvider.externalCommand;

    return DownloadSettings(
      saveDirectory:
          (json['saveDirectory'] as String?) ?? defaultSaveDirectory(),
      downloadMode: _parseDownloadMode(json['downloadMode']),
      concurrentCount:
          parseCount(json['concurrentCount']) ?? defaults.concurrentCount,
      defaultQuality:
          (json['defaultQuality'] as String?) ?? defaults.defaultQuality,
      recommendedVariantCount:
          parseCount(json['recommendedVariantCount']) ??
          defaults.recommendedVariantCount,
      downloadSubtitles:
          parseBool(json['downloadSubtitles']) ?? defaults.downloadSubtitles,
      downloadThumbnail:
          parseBool(json['downloadThumbnail']) ?? defaults.downloadThumbnail,
      disclaimerAccepted:
          parseBool(json['disclaimerAccepted']) ?? defaults.disclaimerAccepted,
      logLevel: _parseLogLevel(json['logLevel']) ?? defaults.logLevel,
      aiAnalysisProvider: aiAnalysisProvider,
      builtInClipAnalyzerMode: _parseBuiltInClipAnalyzerMode(
        json['builtInClipAnalyzerMode'],
      ),
      ytDlpPath: json['ytDlpPath'] as String?,
      ffmpegPath: json['ffmpegPath'] as String?,
      aiAnalyzerCommand: aiAnalyzerCommand,
      aiCloudEndpoint: aiCloudEndpoint,
      aiCloudApiKey: json['aiCloudApiKey'] as String?,
      aiCloudModel: json['aiCloudModel'] as String?,
      selectedAiCloudConfigId: json['selectedAiCloudConfigId'] as String?,
      aiCloudConfigs: aiCloudConfigs,
      defaultCookieBrowser: json['defaultCookieBrowser'] as String?,
      autoClipConfig: json['autoClipConfig'] is Map
          ? AutoClipConfig.fromJson(
              Map<String, Object?>.from(json['autoClipConfig'] as Map),
            )
          : AutoClipConfig.defaults,
    ).normalized();
  }

  static Object? _decodeJsonList(Object? value) {
    if (value is! String) return value;
    final trimmed = value.trim();
    if (!trimmed.startsWith('[')) return value;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  static LogLevel? _parseLogLevel(dynamic v) {
    if (v is LogLevel) return v;
    if (v is String) {
      try {
        return LogLevel.values.byName(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static List<AiCloudConfig> _normalizeAiCloudConfigs(
    List<AiCloudConfig> configs, {
    String? legacyEndpoint,
    String? legacyApiKey,
    String? legacyModel,
  }) {
    final normalized = <AiCloudConfig>[];
    final seenIds = <String>{};
    for (final config in configs) {
      final normalizedConfig = config.normalized();
      if (normalizedConfig.id.isEmpty ||
          seenIds.contains(normalizedConfig.id)) {
        continue;
      }
      seenIds.add(normalizedConfig.id);
      normalized.add(normalizedConfig);
    }
    if (normalized.isEmpty &&
        (legacyEndpoint != null ||
            legacyApiKey != null ||
            legacyModel != null)) {
      normalized.add(
        AiCloudConfig(
          id: 'legacy-cloud',
          vendor: AiCloudVendor.custom,
          name: 'Legacy cloud endpoint',
          endpoint: legacyEndpoint ?? '',
          model: legacyModel ?? '',
          apiKey: legacyApiKey,
        ).normalized(),
      );
    }
    return List.unmodifiable(normalized);
  }

  static String? _selectedAiCloudConfigId(
    String? selectedId,
    List<AiCloudConfig> configs,
  ) {
    final normalizedSelectedId = _normalizeStaticOptionalPath(selectedId);
    if (configs.isEmpty) return null;
    if (normalizedSelectedId != null &&
        configs.any((config) => config.id == normalizedSelectedId)) {
      return normalizedSelectedId;
    }
    return configs.first.id;
  }

  static AiCloudConfig? _findAiCloudConfig(
    String? id,
    List<AiCloudConfig> configs,
  ) {
    if (id == null) return configs.isEmpty ? null : configs.first;
    for (final config in configs) {
      if (config.id == id) return config;
    }
    return configs.isEmpty ? null : configs.first;
  }

  static DownloadMode _parseDownloadMode(Object? value) {
    if (value is String) {
      return DownloadMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => defaults.downloadMode,
      );
    }
    return defaults.downloadMode;
  }

  static AiAnalysisProvider _parseAiAnalysisProvider(Object? value) {
    if (value is String) {
      return AiAnalysisProvider.values.firstWhere(
        (provider) => provider.name == value,
        orElse: () => defaults.aiAnalysisProvider,
      );
    }
    return defaults.aiAnalysisProvider;
  }

  static String? _normalizeStaticOptionalPath(String? path) {
    final trimmed = path?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static BuiltInClipAnalyzerMode _parseBuiltInClipAnalyzerMode(Object? value) {
    if (value is String) {
      return BuiltInClipAnalyzerMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => defaults.builtInClipAnalyzerMode,
      );
    }
    return defaults.builtInClipAnalyzerMode;
  }
}

enum ResourceType { audio, video }

class ResourceVariant {
  const ResourceVariant({
    required this.label,
    required this.description,
    required this.isRecommended,
    this.formatId,
    this.type,
    this.height,
    this.filesize,
    this.videoId,
    this.videoTitle,
  });

  final String label;
  final String description;
  final bool isRecommended;
  final String? formatId;
  final ResourceType? type;
  final int? height;
  final int? filesize;
  final String? videoId;
  final String? videoTitle;

  Map<String, Object?> toJson() => {
    'label': label,
    'description': description,
    'isRecommended': isRecommended,
    if (formatId != null) 'formatId': formatId,
    if (type != null) 'type': type!.name,
    if (height != null) 'height': height,
    if (filesize != null) 'filesize': filesize,
    if (videoId != null) 'videoId': videoId,
    if (videoTitle != null) 'videoTitle': videoTitle,
  };

  factory ResourceVariant.fromJson(Map<String, Object?> json) {
    final typeStr = json['type'] as String?;
    return ResourceVariant(
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isRecommended: json['isRecommended'] as bool? ?? false,
      formatId: json['formatId'] as String?,
      type: typeStr != null
          ? ResourceType.values.firstWhere(
              (t) => t.name == typeStr,
              orElse: () => ResourceType.video,
            )
          : null,
      height: json['height'] as int?,
      filesize: json['filesize'] as int?,
      videoId: json['videoId'] as String?,
      videoTitle: json['videoTitle'] as String?,
    );
  }
}

class CookieConfig {
  const CookieConfig({
    required this.domain,
    required this.browser,
    required this.cookieFile,
    this.importedAt,
    this.enabled = true,
  });

  final String domain;
  final String browser;
  final String cookieFile;
  final DateTime? importedAt;
  final bool enabled;

  bool get isExpired =>
      importedAt == null || DateTime.now().difference(importedAt!).inDays >= 7;

  CookieConfig copyWith({
    String? domain,
    String? browser,
    String? cookieFile,
    Object? importedAt = _unchanged,
    bool? enabled,
  }) {
    return CookieConfig(
      domain: domain ?? this.domain,
      browser: browser ?? this.browser,
      cookieFile: cookieFile ?? this.cookieFile,
      importedAt: importedAt == _unchanged
          ? this.importedAt
          : importedAt as DateTime?,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toJson() => {
    'domain': domain,
    'browser': browser,
    'cookieFile': cookieFile,
    if (importedAt != null) 'importedAt': importedAt!.toIso8601String(),
    'enabled': enabled,
  };

  factory CookieConfig.fromJson(Map<String, Object?> json) {
    final importedStr = json['importedAt'] as String?;
    return CookieConfig(
      domain: json['domain'] as String? ?? '',
      browser: json['browser'] as String? ?? 'chrome',
      cookieFile: json['cookieFile'] as String? ?? '',
      importedAt: importedStr != null ? DateTime.tryParse(importedStr) : null,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

const Object _unchanged = Object();

DateTime? _parseDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Map<String, Object?> _readObjectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

List<String> _readStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) return _readStringList(decoded);
    } catch (_) {
      return trimmed.split(RegExp(r'\s+'));
    }
  }
  return const <String>[];
}

List<double> _readDoubleList(Object? value) {
  if (value is List) {
    return value.whereType<num>().map((item) => item.toDouble()).toList();
  }
  return const <double>[];
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is T) return value;
  if (value is String) {
    return values.firstWhere(
      (item) => item.name == value,
      orElse: () => fallback,
    );
  }
  return fallback;
}

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.title,
    required this.source,
    required this.status,
    required this.progress,
    required List<ResourceVariant> variants,
    this.errorMessage,
    this.speed,
    this.eta,
    this.mediaPath,
  }) : variants = List.unmodifiable(variants);

  final String id;
  final String title;
  final String source;
  final DownloadStatus status;
  final double progress;
  final List<ResourceVariant> variants;
  final String? errorMessage;
  final String? speed;
  final String? eta;
  final String? mediaPath;

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    Object? errorMessage = _unchanged,
    Object? speed = _unchanged,
    Object? eta = _unchanged,
    Object? mediaPath = _unchanged,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      source: source,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      variants: variants,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
      speed: speed == _unchanged ? this.speed : speed as String?,
      eta: eta == _unchanged ? this.eta : eta as String?,
      mediaPath: mediaPath == _unchanged
          ? this.mediaPath
          : mediaPath as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'source': source,
    'status': status.name,
    'progress': progress,
    'variants': variants.map((v) => v.toJson()).toList(),
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (speed != null) 'speed': speed,
    if (eta != null) 'eta': eta,
    if (mediaPath != null) 'mediaPath': mediaPath,
  };

  factory DownloadTask.fromJson(Map<String, Object?> json) {
    final variantsList =
        (json['variants'] as List<Object?>?)
            ?.whereType<Map<String, Object?>>()
            .map(ResourceVariant.fromJson)
            .toList() ??
        const [];
    final statusStr = json['status'] as String?;
    return DownloadTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      source: json['source'] as String? ?? '',
      status: statusStr != null
          ? DownloadStatus.values.firstWhere(
              (s) => s.name == statusStr,
              orElse: () => DownloadStatus.paused,
            )
          : DownloadStatus.paused,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      variants: variantsList,
      errorMessage: json['errorMessage'] as String?,
      speed: json['speed'] as String?,
      eta: json['eta'] as String?,
      mediaPath: json['mediaPath'] as String?,
    );
  }
}

enum PostProcessTaskType { clip, aiClipAnalysis }

enum PostProcessStatus { queued, running, completed, failed, cancelled }

class ClipDetection {
  ClipDetection({
    required this.id,
    required this.segmentId,
    required this.timestampMs,
    required this.label,
    required this.confidence,
    List<double> bbox = const [],
    this.trackId,
  }) : bbox = List.unmodifiable(bbox);

  final String id;
  final String segmentId;
  final int timestampMs;
  final String label;
  final double confidence;
  final List<double> bbox;
  final String? trackId;

  Map<String, Object?> toJson() => {
    'id': id,
    'segmentId': segmentId,
    'timestampMs': timestampMs,
    'label': label,
    'confidence': confidence,
    'bbox': bbox,
    if (trackId != null) 'trackId': trackId,
  };

  factory ClipDetection.fromJson(Map<String, Object?> json) {
    return ClipDetection(
      id: json['id'] as String? ?? '',
      segmentId: json['segmentId'] as String? ?? '',
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      bbox:
          (json['bbox'] as List<Object?>?)
              ?.whereType<num>()
              .map((v) => v.toDouble())
              .toList() ??
          const <double>[],
      trackId: json['trackId'] as String?,
    );
  }
}

class ClipTranscript {
  ClipTranscript({
    required this.id,
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.text,
    List<String> words = const [],
  }) : words = List.unmodifiable(words);

  final String id;
  final String segmentId;
  final int startMs;
  final int endMs;
  final String text;
  final List<String> words;

  Map<String, Object?> toJson() => {
    'id': id,
    'segmentId': segmentId,
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    'words': words,
  };

  factory ClipTranscript.fromJson(Map<String, Object?> json) {
    return ClipTranscript(
      id: json['id'] as String? ?? '',
      segmentId: json['segmentId'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      words:
          (json['words'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
    );
  }
}

class ClipSegment {
  ClipSegment({
    required this.id,
    required this.sourceTaskId,
    required this.postProcessTaskId,
    required this.sourcePath,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.summary,
    List<String> keywords = const [],
    List<String> tags = const [],
    required this.confidence,
    required this.reason,
    List<ClipDetection> detections = const [],
    List<ClipTranscript> transcripts = const [],
    this.adjustedStartMs,
    this.adjustedEndMs,
    this.outputPath,
    DateTime? createdAt,
  }) : keywords = List.unmodifiable(keywords),
       tags = List.unmodifiable(tags),
       detections = List.unmodifiable(detections),
       transcripts = List.unmodifiable(transcripts),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String sourceTaskId;
  final String postProcessTaskId;
  final String sourcePath;
  final int startMs;
  final int endMs;
  final int? adjustedStartMs;
  final int? adjustedEndMs;
  final String title;
  final String summary;
  final List<String> keywords;
  final List<String> tags;
  final double confidence;
  final String reason;
  final List<ClipDetection> detections;
  final List<ClipTranscript> transcripts;
  final String? outputPath;
  final DateTime createdAt;

  int get effectiveStartMs => adjustedStartMs ?? startMs;
  int get effectiveEndMs => adjustedEndMs ?? endMs;

  ClipSegment copyWith({
    Object? adjustedStartMs = _unchanged,
    Object? adjustedEndMs = _unchanged,
    Object? outputPath = _unchanged,
  }) {
    return ClipSegment(
      id: id,
      sourceTaskId: sourceTaskId,
      postProcessTaskId: postProcessTaskId,
      sourcePath: sourcePath,
      startMs: startMs,
      endMs: endMs,
      adjustedStartMs: adjustedStartMs == _unchanged
          ? this.adjustedStartMs
          : adjustedStartMs as int?,
      adjustedEndMs: adjustedEndMs == _unchanged
          ? this.adjustedEndMs
          : adjustedEndMs as int?,
      title: title,
      summary: summary,
      keywords: keywords,
      tags: tags,
      confidence: confidence,
      reason: reason,
      detections: detections,
      transcripts: transcripts,
      outputPath: outputPath == _unchanged
          ? this.outputPath
          : outputPath as String?,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceTaskId': sourceTaskId,
    'postProcessTaskId': postProcessTaskId,
    'sourcePath': sourcePath,
    'startMs': startMs,
    'endMs': endMs,
    if (adjustedStartMs != null) 'adjustedStartMs': adjustedStartMs,
    if (adjustedEndMs != null) 'adjustedEndMs': adjustedEndMs,
    'title': title,
    'summary': summary,
    'keywords': keywords,
    'tags': tags,
    'confidence': confidence,
    'reason': reason,
    'detections': detections.map((d) => d.toJson()).toList(),
    'transcripts': transcripts.map((t) => t.toJson()).toList(),
    if (outputPath != null) 'outputPath': outputPath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ClipSegment.fromJson(Map<String, Object?> json) {
    final createdAtStr = json['createdAt'] as String?;
    return ClipSegment(
      id: json['id'] as String? ?? '',
      sourceTaskId: json['sourceTaskId'] as String? ?? '',
      postProcessTaskId: json['postProcessTaskId'] as String? ?? '',
      sourcePath: json['sourcePath'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      adjustedStartMs: (json['adjustedStartMs'] as num?)?.toInt(),
      adjustedEndMs: (json['adjustedEndMs'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      keywords:
          (json['keywords'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
      tags:
          (json['tags'] as List<Object?>?)?.whereType<String>().toList() ??
          const <String>[],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      reason: json['reason'] as String? ?? '',
      detections:
          (json['detections'] as List<Object?>?)
              ?.whereType<Map<String, Object?>>()
              .map(ClipDetection.fromJson)
              .toList() ??
          const <ClipDetection>[],
      transcripts:
          (json['transcripts'] as List<Object?>?)
              ?.whereType<Map<String, Object?>>()
              .map(ClipTranscript.fromJson)
              .toList() ??
          const <ClipTranscript>[],
      outputPath: json['outputPath'] as String?,
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) : null,
    );
  }
}

class PostProcessTask {
  PostProcessTask({
    required this.id,
    required this.sourceTaskId,
    required this.title,
    required this.type,
    required this.status,
    required this.progress,
    required this.sourcePath,
    required this.outputDirectory,
    List<String> outputPaths = const [],
    List<ClipSegment> clipSegments = const [],
    this.errorMessage,
  }) : outputPaths = List.unmodifiable(outputPaths),
       clipSegments = List.unmodifiable(clipSegments);

  final String id;
  final String sourceTaskId;
  final String title;
  final PostProcessTaskType type;
  final PostProcessStatus status;
  final double progress;
  final String sourcePath;
  final String outputDirectory;
  final List<String> outputPaths;
  final List<ClipSegment> clipSegments;
  final String? errorMessage;

  PostProcessTask copyWith({
    PostProcessStatus? status,
    double? progress,
    Object? outputPaths = _unchanged,
    Object? clipSegments = _unchanged,
    Object? errorMessage = _unchanged,
  }) {
    return PostProcessTask(
      id: id,
      sourceTaskId: sourceTaskId,
      title: title,
      type: type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sourcePath: sourcePath,
      outputDirectory: outputDirectory,
      outputPaths: outputPaths == _unchanged
          ? this.outputPaths
          : outputPaths as List<String>,
      clipSegments: clipSegments == _unchanged
          ? this.clipSegments
          : clipSegments as List<ClipSegment>,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceTaskId': sourceTaskId,
    'title': title,
    'type': type.name,
    'status': status.name,
    'progress': progress,
    'sourcePath': sourcePath,
    'outputDirectory': outputDirectory,
    'outputPaths': outputPaths,
    'clipSegments': clipSegments.map((s) => s.toJson()).toList(),
    if (errorMessage != null) 'errorMessage': errorMessage,
  };

  factory PostProcessTask.fromJson(Map<String, Object?> json) {
    final typeStr = json['type'] as String?;
    final statusStr = json['status'] as String?;
    final outputs =
        (json['outputPaths'] as List<Object?>?)?.whereType<String>().toList() ??
        const <String>[];
    final segments =
        (json['clipSegments'] as List<Object?>?)
            ?.whereType<Map<String, Object?>>()
            .map(ClipSegment.fromJson)
            .toList() ??
        const <ClipSegment>[];

    return PostProcessTask(
      id: json['id'] as String? ?? '',
      sourceTaskId: json['sourceTaskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: typeStr != null
          ? PostProcessTaskType.values.firstWhere(
              (t) => t.name == typeStr,
              orElse: () => PostProcessTaskType.clip,
            )
          : PostProcessTaskType.clip,
      status: statusStr != null
          ? PostProcessStatus.values.firstWhere(
              (s) => s.name == statusStr,
              orElse: () => PostProcessStatus.queued,
            )
          : PostProcessStatus.queued,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      sourcePath: json['sourcePath'] as String? ?? '',
      outputDirectory: json['outputDirectory'] as String? ?? '',
      outputPaths: outputs,
      clipSegments: segments,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

// ────────────────────────────────────────────────────────────
// Auto-Clip
// ────────────────────────────────────────────────────────────

class AutoClipConfig {
  const AutoClipConfig({
    this.enabled = true,
    this.minConfidence = 0.7,
    this.maxClipsPerVideo = 5,
    this.maxClipDurationSec = 60,
    this.startOffsetMs = -500,
    this.endOffsetMs = 500,
  });

  static const defaults = AutoClipConfig();

  final bool enabled;
  final double minConfidence;
  final int maxClipsPerVideo;
  final int maxClipDurationSec;
  final int startOffsetMs;
  final int endOffsetMs;

  AutoClipConfig copyWith({
    bool? enabled,
    double? minConfidence,
    int? maxClipsPerVideo,
    int? maxClipDurationSec,
    int? startOffsetMs,
    int? endOffsetMs,
  }) {
    return AutoClipConfig(
      enabled: enabled ?? this.enabled,
      minConfidence: minConfidence ?? this.minConfidence,
      maxClipsPerVideo: maxClipsPerVideo ?? this.maxClipsPerVideo,
      maxClipDurationSec: maxClipDurationSec ?? this.maxClipDurationSec,
      startOffsetMs: startOffsetMs ?? this.startOffsetMs,
      endOffsetMs: endOffsetMs ?? this.endOffsetMs,
    );
  }

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'minConfidence': minConfidence,
    'maxClipsPerVideo': maxClipsPerVideo,
    'maxClipDurationSec': maxClipDurationSec,
    'startOffsetMs': startOffsetMs,
    'endOffsetMs': endOffsetMs,
  };

  factory AutoClipConfig.fromJson(Map<String, Object?> json) {
    double? parseDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return AutoClipConfig(
      enabled: json['enabled'] as bool? ?? defaults.enabled,
      minConfidence:
          parseDouble(json['minConfidence']) ?? defaults.minConfidence,
      maxClipsPerVideo:
          parseInt(json['maxClipsPerVideo']) ?? defaults.maxClipsPerVideo,
      maxClipDurationSec:
          parseInt(json['maxClipDurationSec']) ?? defaults.maxClipDurationSec,
      startOffsetMs: parseInt(json['startOffsetMs']) ?? defaults.startOffsetMs,
      endOffsetMs: parseInt(json['endOffsetMs']) ?? defaults.endOffsetMs,
    );
  }
}

class ClipRecord {
  ClipRecord({
    required this.id,
    required this.sourceTaskId,
    required this.sourcePath,
    this.outputPath,
    required this.title,
    required this.confidence,
    required this.startMs,
    required this.endMs,
    required this.durationMs,
    this.status = ClipRecordStatus.pending,
    this.progress = 0,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String sourceTaskId;
  final String sourcePath;
  final String? outputPath;
  final String title;
  final double confidence;
  final int startMs;
  final int endMs;
  final int durationMs;
  final ClipRecordStatus status;
  final int progress;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  ClipRecord copyWith({
    String? id,
    String? sourceTaskId,
    String? sourcePath,
    Object? outputPath = _unchanged,
    String? title,
    double? confidence,
    int? startMs,
    int? endMs,
    int? durationMs,
    ClipRecordStatus? status,
    int? progress,
    Object? errorMessage = _unchanged,
    DateTime? completedAt,
  }) {
    return ClipRecord(
      id: id ?? this.id,
      sourceTaskId: sourceTaskId ?? this.sourceTaskId,
      sourcePath: sourcePath ?? this.sourcePath,
      outputPath: outputPath == _unchanged
          ? this.outputPath
          : outputPath as String?,
      title: title ?? this.title,
      confidence: confidence ?? this.confidence,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'sourceTaskId': sourceTaskId,
    'sourcePath': sourcePath,
    if (outputPath != null) 'outputPath': outputPath!,
    'title': title,
    'confidence': confidence,
    'startMs': startMs,
    'endMs': endMs,
    'durationMs': durationMs,
    'status': status.name,
    'progress': progress,
    if (errorMessage != null) 'errorMessage': errorMessage!,
    'createdAt': createdAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory ClipRecord.fromJson(Map<String, Object?> json) {
    final statusStr = json['status'] as String?;
    return ClipRecord(
      id: json['id'] as String? ?? '',
      sourceTaskId: json['sourceTaskId'] as String? ?? '',
      sourcePath: json['sourcePath'] as String? ?? '',
      outputPath: json['outputPath'] as String?,
      title: json['title'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      status: statusStr != null
          ? ClipRecordStatus.values.firstWhere(
              (s) => s.name == statusStr,
              orElse: () => ClipRecordStatus.pending,
            )
          : ClipRecordStatus.pending,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }
}

// ────────────────────────────────────────────────────────────
// Edge + Cloud Media Library
// ────────────────────────────────────────────────────────────

enum MediaAssetType { video, audio }

enum MediaJobRuntime { local, cloud }

enum MediaAnalysisStatus { queued, running, completed, failed, cancelled }

enum ClipCandidateSource { local, cloud, user, legacy }

enum ClipExportStatus { pending, cutting, completed, failed, cancelled }

enum MediaVectorTargetType { media, transcript, frame, candidate, export }

enum MediaVectorModality { text, image, audio, multimodal }

enum CloudUploadPolicy { manifestOnly, selectedClips, originalOnConfirm }

enum CloudSyncTaskType {
  uploadManifest,
  uploadClip,
  uploadOriginal,
  createClipJob,
  pullResult,
}

enum CloudSyncStatus {
  pending,
  uploading,
  queued,
  running,
  completed,
  failed,
  cancelled,
}

class MediaAsset {
  MediaAsset({
    required this.id,
    required this.sourceTaskId,
    required this.sourceUrl,
    required this.title,
    required this.mediaPath,
    required this.mediaType,
    required this.fileSha256,
    required this.durationMs,
    required this.fileSizeBytes,
    this.author,
    this.thumbnailPath,
    Map<String, Object?> metadata = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : metadata = Map.unmodifiable(metadata),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String sourceTaskId;
  final String sourceUrl;
  final String title;
  final String? author;
  final String mediaPath;
  final MediaAssetType mediaType;
  final String fileSha256;
  final int durationMs;
  final int fileSizeBytes;
  final String? thumbnailPath;
  final Map<String, Object?> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  MediaAsset copyWith({
    String? id,
    String? sourceTaskId,
    String? sourceUrl,
    String? title,
    Object? author = _unchanged,
    String? mediaPath,
    MediaAssetType? mediaType,
    String? fileSha256,
    int? durationMs,
    int? fileSizeBytes,
    Object? thumbnailPath = _unchanged,
    Map<String, Object?>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaAsset(
      id: id ?? this.id,
      sourceTaskId: sourceTaskId ?? this.sourceTaskId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      title: title ?? this.title,
      author: author == _unchanged ? this.author : author as String?,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      fileSha256: fileSha256 ?? this.fileSha256,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailPath: thumbnailPath == _unchanged
          ? this.thumbnailPath
          : thumbnailPath as String?,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceTaskId': sourceTaskId,
    'sourceUrl': sourceUrl,
    'title': title,
    if (author != null) 'author': author,
    'mediaPath': mediaPath,
    'mediaType': mediaType.name,
    'fileSha256': fileSha256,
    'durationMs': durationMs,
    'fileSizeBytes': fileSizeBytes,
    if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MediaAsset.fromJson(Map<String, Object?> json) {
    final createdAt = _parseDateTime(json['createdAt']) ?? DateTime.now();
    return MediaAsset(
      id: json['id'] as String? ?? '',
      sourceTaskId: json['sourceTaskId'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      mediaPath: json['mediaPath'] as String? ?? '',
      mediaType: _enumByName(
        MediaAssetType.values,
        json['mediaType'],
        MediaAssetType.video,
      ),
      fileSha256: json['fileSha256'] as String? ?? '',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      thumbnailPath: json['thumbnailPath'] as String?,
      metadata: _readObjectMap(json['metadata']),
      createdAt: createdAt,
      updatedAt: _parseDateTime(json['updatedAt']) ?? createdAt,
    );
  }
}

class MediaAnalysisJob {
  MediaAnalysisJob({
    required this.id,
    required this.mediaAssetId,
    required this.runtime,
    required this.status,
    required this.progress,
    List<String> stages = const [],
    this.errorMessage,
    this.manifestPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : stages = List.unmodifiable(stages),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String mediaAssetId;
  final MediaJobRuntime runtime;
  final MediaAnalysisStatus status;
  final double progress;
  final List<String> stages;
  final String? errorMessage;
  final String? manifestPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  MediaAnalysisJob copyWith({
    String? id,
    String? mediaAssetId,
    MediaJobRuntime? runtime,
    MediaAnalysisStatus? status,
    double? progress,
    List<String>? stages,
    Object? errorMessage = _unchanged,
    Object? manifestPath = _unchanged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MediaAnalysisJob(
      id: id ?? this.id,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      runtime: runtime ?? this.runtime,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      stages: stages ?? this.stages,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
      manifestPath: manifestPath == _unchanged
          ? this.manifestPath
          : manifestPath as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaAssetId': mediaAssetId,
    'runtime': runtime.name,
    'status': status.name,
    'progress': progress,
    'stages': stages,
    if (errorMessage != null) 'errorMessage': errorMessage,
    if (manifestPath != null) 'manifestPath': manifestPath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MediaAnalysisJob.fromJson(Map<String, Object?> json) {
    final createdAt = _parseDateTime(json['createdAt']) ?? DateTime.now();
    return MediaAnalysisJob(
      id: json['id'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      runtime: _enumByName(
        MediaJobRuntime.values,
        json['runtime'],
        MediaJobRuntime.local,
      ),
      status: _enumByName(
        MediaAnalysisStatus.values,
        json['status'],
        MediaAnalysisStatus.queued,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      stages: _readStringList(json['stages']),
      errorMessage: json['errorMessage'] as String?,
      manifestPath: json['manifestPath'] as String?,
      createdAt: createdAt,
      updatedAt: _parseDateTime(json['updatedAt']) ?? createdAt,
    );
  }
}

class ClipCandidate {
  ClipCandidate({
    required this.id,
    required this.mediaAssetId,
    required this.startMs,
    required this.endMs,
    required this.title,
    required this.summary,
    List<String> tags = const [],
    List<String> keywords = const [],
    required this.score,
    Map<String, double> scoreBreakdown = const {},
    List<String> evidenceIds = const [],
    required this.reason,
    this.source = ClipCandidateSource.local,
    DateTime? createdAt,
  }) : tags = List.unmodifiable(tags),
       keywords = List.unmodifiable(keywords),
       scoreBreakdown = Map.unmodifiable(scoreBreakdown),
       evidenceIds = List.unmodifiable(evidenceIds),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String mediaAssetId;
  final int startMs;
  final int endMs;
  final String title;
  final String summary;
  final List<String> tags;
  final List<String> keywords;
  final double score;
  final Map<String, double> scoreBreakdown;
  final List<String> evidenceIds;
  final String reason;
  final ClipCandidateSource source;
  final DateTime createdAt;

  int get durationMs => endMs - startMs;

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaAssetId': mediaAssetId,
    'startMs': startMs,
    'endMs': endMs,
    'title': title,
    'summary': summary,
    'tags': tags,
    'keywords': keywords,
    'score': score,
    'scoreBreakdown': scoreBreakdown,
    'evidenceIds': evidenceIds,
    'reason': reason,
    'source': source.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ClipCandidate.fromJson(Map<String, Object?> json) {
    final rawBreakdown = _readObjectMap(json['scoreBreakdown']);
    return ClipCandidate(
      id: json['id'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      tags: _readStringList(json['tags']),
      keywords: _readStringList(json['keywords']),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      scoreBreakdown: rawBreakdown.map(
        (key, value) => MapEntry(key, (value as num?)?.toDouble() ?? 0),
      ),
      evidenceIds: _readStringList(json['evidenceIds']),
      reason: json['reason'] as String? ?? '',
      source: _enumByName(
        ClipCandidateSource.values,
        json['source'],
        ClipCandidateSource.local,
      ),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }
}

class ClipExportRecord {
  ClipExportRecord({
    required this.id,
    required this.mediaAssetId,
    this.candidateId,
    required this.startMs,
    required this.endMs,
    required this.outputPath,
    this.status = ClipExportStatus.pending,
    this.progress = 0,
    this.runtime = MediaJobRuntime.local,
    this.cloudJobId,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String mediaAssetId;
  final String? candidateId;
  final int startMs;
  final int endMs;
  final String outputPath;
  final ClipExportStatus status;
  final int progress;
  final MediaJobRuntime runtime;
  final String? cloudJobId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  int get durationMs => endMs - startMs;

  ClipExportRecord copyWith({
    String? id,
    String? mediaAssetId,
    Object? candidateId = _unchanged,
    int? startMs,
    int? endMs,
    String? outputPath,
    ClipExportStatus? status,
    int? progress,
    MediaJobRuntime? runtime,
    Object? cloudJobId = _unchanged,
    Object? errorMessage = _unchanged,
    DateTime? createdAt,
    Object? completedAt = _unchanged,
  }) {
    return ClipExportRecord(
      id: id ?? this.id,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      candidateId: candidateId == _unchanged
          ? this.candidateId
          : candidateId as String?,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      runtime: runtime ?? this.runtime,
      cloudJobId: cloudJobId == _unchanged
          ? this.cloudJobId
          : cloudJobId as String?,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt == _unchanged
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaAssetId': mediaAssetId,
    if (candidateId != null) 'candidateId': candidateId,
    'startMs': startMs,
    'endMs': endMs,
    'outputPath': outputPath,
    'status': status.name,
    'progress': progress,
    'runtime': runtime.name,
    if (cloudJobId != null) 'cloudJobId': cloudJobId,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory ClipExportRecord.fromJson(Map<String, Object?> json) {
    return ClipExportRecord(
      id: json['id'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      candidateId: json['candidateId'] as String?,
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
      outputPath: json['outputPath'] as String? ?? '',
      status: _enumByName(
        ClipExportStatus.values,
        json['status'],
        ClipExportStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      runtime: _enumByName(
        MediaJobRuntime.values,
        json['runtime'],
        MediaJobRuntime.local,
      ),
      cloudJobId: json['cloudJobId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      completedAt: _parseDateTime(json['completedAt']),
    );
  }
}

class MediaVectorRecord {
  MediaVectorRecord({
    required this.id,
    required this.mediaAssetId,
    required this.targetType,
    required this.targetId,
    this.startMs,
    this.endMs,
    required this.modality,
    required this.model,
    required this.dimension,
    List<double> vector = const [],
    Map<String, Object?> payload = const {},
    DateTime? createdAt,
  }) : vector = List.unmodifiable(vector),
       payload = Map.unmodifiable(payload),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String mediaAssetId;
  final MediaVectorTargetType targetType;
  final String targetId;
  final int? startMs;
  final int? endMs;
  final MediaVectorModality modality;
  final String model;
  final int dimension;
  final List<double> vector;
  final Map<String, Object?> payload;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaAssetId': mediaAssetId,
    'targetType': targetType.name,
    'targetId': targetId,
    if (startMs != null) 'startMs': startMs,
    if (endMs != null) 'endMs': endMs,
    'modality': modality.name,
    'model': model,
    'dimension': dimension,
    'vector': vector,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MediaVectorRecord.fromJson(Map<String, Object?> json) {
    return MediaVectorRecord(
      id: json['id'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      targetType: _enumByName(
        MediaVectorTargetType.values,
        json['targetType'],
        MediaVectorTargetType.media,
      ),
      targetId: json['targetId'] as String? ?? '',
      startMs: (json['startMs'] as num?)?.toInt(),
      endMs: (json['endMs'] as num?)?.toInt(),
      modality: _enumByName(
        MediaVectorModality.values,
        json['modality'],
        MediaVectorModality.text,
      ),
      model: json['model'] as String? ?? '',
      dimension: (json['dimension'] as num?)?.toInt() ?? 0,
      vector: _readDoubleList(json['vector']),
      payload: _readObjectMap(json['payload']),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }
}

class CloudConnectionConfig {
  CloudConnectionConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.deviceName,
    this.accessToken,
    this.enabled = true,
    this.uploadPolicy = CloudUploadPolicy.originalOnConfirm,
    this.maxConcurrentSync = 1,
    this.syncEnabled = false,
    this.pairedAt,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String deviceName;
  final String? accessToken;
  final bool enabled;
  final CloudUploadPolicy uploadPolicy;
  final int maxConcurrentSync;
  final bool syncEnabled;
  final DateTime? pairedAt;

  bool get isPaired => accessToken != null && accessToken!.trim().isNotEmpty;

  CloudConnectionConfig normalized() {
    return CloudConnectionConfig(
      id: id.trim(),
      name: name.trim().isEmpty ? 'Personal Cloud' : name.trim(),
      baseUrl: baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
      deviceName: deviceName.trim(),
      accessToken: accessToken?.trim().isEmpty == true
          ? null
          : accessToken?.trim(),
      enabled: enabled,
      uploadPolicy: uploadPolicy,
      maxConcurrentSync: maxConcurrentSync.clamp(1, 8).toInt(),
      syncEnabled: syncEnabled,
      pairedAt: pairedAt,
    );
  }

  CloudConnectionConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? deviceName,
    Object? accessToken = _unchanged,
    bool? enabled,
    CloudUploadPolicy? uploadPolicy,
    int? maxConcurrentSync,
    bool? syncEnabled,
    Object? pairedAt = _unchanged,
  }) {
    return CloudConnectionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      deviceName: deviceName ?? this.deviceName,
      accessToken: accessToken == _unchanged
          ? this.accessToken
          : accessToken as String?,
      enabled: enabled ?? this.enabled,
      uploadPolicy: uploadPolicy ?? this.uploadPolicy,
      maxConcurrentSync: maxConcurrentSync ?? this.maxConcurrentSync,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      pairedAt: pairedAt == _unchanged ? this.pairedAt : pairedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'deviceName': deviceName,
    if (accessToken != null) 'accessToken': accessToken,
    'enabled': enabled,
    'uploadPolicy': uploadPolicy.name,
    'maxConcurrentSync': maxConcurrentSync,
    'syncEnabled': syncEnabled,
    if (pairedAt != null) 'pairedAt': pairedAt!.toIso8601String(),
  };

  factory CloudConnectionConfig.fromJson(Map<String, Object?> json) {
    return CloudConnectionConfig(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      accessToken: json['accessToken'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      uploadPolicy: _enumByName(
        CloudUploadPolicy.values,
        json['uploadPolicy'],
        CloudUploadPolicy.originalOnConfirm,
      ),
      maxConcurrentSync: (json['maxConcurrentSync'] as num?)?.toInt() ?? 1,
      syncEnabled: json['syncEnabled'] as bool? ?? false,
      pairedAt: _parseDateTime(json['pairedAt']),
    ).normalized();
  }
}

class CloudSyncTask {
  CloudSyncTask({
    required this.id,
    required this.mediaAssetId,
    required this.type,
    required this.status,
    required this.idempotencyKey,
    this.uploadedBytes = 0,
    this.totalBytes = 0,
    this.cloudMediaId,
    this.cloudJobId,
    this.errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  final String mediaAssetId;
  final CloudSyncTaskType type;
  final CloudSyncStatus status;
  final String idempotencyKey;
  final int uploadedBytes;
  final int totalBytes;
  final String? cloudMediaId;
  final String? cloudJobId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get progress => totalBytes <= 0 ? 0 : uploadedBytes / totalBytes;

  CloudSyncTask copyWith({
    String? id,
    String? mediaAssetId,
    CloudSyncTaskType? type,
    CloudSyncStatus? status,
    String? idempotencyKey,
    int? uploadedBytes,
    int? totalBytes,
    Object? cloudMediaId = _unchanged,
    Object? cloudJobId = _unchanged,
    Object? errorMessage = _unchanged,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CloudSyncTask(
      id: id ?? this.id,
      mediaAssetId: mediaAssetId ?? this.mediaAssetId,
      type: type ?? this.type,
      status: status ?? this.status,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      uploadedBytes: uploadedBytes ?? this.uploadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      cloudMediaId: cloudMediaId == _unchanged
          ? this.cloudMediaId
          : cloudMediaId as String?,
      cloudJobId: cloudJobId == _unchanged
          ? this.cloudJobId
          : cloudJobId as String?,
      errorMessage: errorMessage == _unchanged
          ? this.errorMessage
          : errorMessage as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'mediaAssetId': mediaAssetId,
    'type': type.name,
    'status': status.name,
    'idempotencyKey': idempotencyKey,
    'uploadedBytes': uploadedBytes,
    'totalBytes': totalBytes,
    if (cloudMediaId != null) 'cloudMediaId': cloudMediaId,
    if (cloudJobId != null) 'cloudJobId': cloudJobId,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CloudSyncTask.fromJson(Map<String, Object?> json) {
    final createdAt = _parseDateTime(json['createdAt']) ?? DateTime.now();
    return CloudSyncTask(
      id: json['id'] as String? ?? '',
      mediaAssetId: json['mediaAssetId'] as String? ?? '',
      type: _enumByName(
        CloudSyncTaskType.values,
        json['type'],
        CloudSyncTaskType.uploadManifest,
      ),
      status: _enumByName(
        CloudSyncStatus.values,
        json['status'],
        CloudSyncStatus.pending,
      ),
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      uploadedBytes: (json['uploadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      cloudMediaId: json['cloudMediaId'] as String?,
      cloudJobId: json['cloudJobId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      createdAt: createdAt,
      updatedAt: _parseDateTime(json['updatedAt']) ?? createdAt,
    );
  }
}
