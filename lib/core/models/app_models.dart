import 'dart:io';

enum DownloadMode { serial, queue, concurrent }

enum AiAnalysisProvider { builtIn, externalCommand, cloudEndpoint }

enum BuiltInClipAnalyzerMode { balanced, visualFocused, audioFocused }

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
    this.aiAnalysisProvider = AiAnalysisProvider.builtIn,
    this.builtInClipAnalyzerMode = BuiltInClipAnalyzerMode.balanced,
    this.ytDlpPath,
    this.ffmpegPath,
    this.aiAnalyzerCommand,
    this.aiCloudEndpoint,
    this.aiCloudApiKey,
    this.aiCloudModel,
    this.cookieConfigs = const [],
    this.defaultCookieBrowser,
  });

  static const defaults = DownloadSettings(
    saveDirectory: '',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
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
  final bool downloadSubtitles;
  final bool downloadThumbnail;
  final bool disclaimerAccepted;
  final AiAnalysisProvider aiAnalysisProvider;
  final BuiltInClipAnalyzerMode builtInClipAnalyzerMode;
  final String? ytDlpPath;
  final String? ffmpegPath;
  final String? aiAnalyzerCommand;
  final String? aiCloudEndpoint;
  final String? aiCloudApiKey;
  final String? aiCloudModel;
  final List<CookieConfig> cookieConfigs;
  final String? defaultCookieBrowser;

  DownloadSettings copyWith({
    String? saveDirectory,
    DownloadMode? downloadMode,
    int? concurrentCount,
    String? defaultQuality,
    bool? downloadSubtitles,
    bool? downloadThumbnail,
    bool? disclaimerAccepted,
    AiAnalysisProvider? aiAnalysisProvider,
    BuiltInClipAnalyzerMode? builtInClipAnalyzerMode,
    Object? ytDlpPath = _unchanged,
    Object? ffmpegPath = _unchanged,
    Object? aiAnalyzerCommand = _unchanged,
    Object? aiCloudEndpoint = _unchanged,
    Object? aiCloudApiKey = _unchanged,
    Object? aiCloudModel = _unchanged,
    Object? cookieConfigs = _unchanged,
    Object? defaultCookieBrowser = _unchanged,
  }) {
    return DownloadSettings(
      saveDirectory: saveDirectory ?? this.saveDirectory,
      downloadMode: downloadMode ?? this.downloadMode,
      concurrentCount: concurrentCount ?? this.concurrentCount,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      downloadThumbnail: downloadThumbnail ?? this.downloadThumbnail,
      disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
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
      cookieConfigs: cookieConfigs == _unchanged
          ? this.cookieConfigs
          : cookieConfigs as List<CookieConfig>,
      defaultCookieBrowser: defaultCookieBrowser == _unchanged
          ? this.defaultCookieBrowser
          : defaultCookieBrowser as String?,
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

    return DownloadSettings(
      saveDirectory: normalizedSaveDirectory,
      downloadMode: downloadMode,
      concurrentCount: concurrentCount.clamp(1, 8).toInt(),
      defaultQuality: normalizedDefaultQuality,
      downloadSubtitles: downloadSubtitles,
      downloadThumbnail: downloadThumbnail,
      disclaimerAccepted: disclaimerAccepted,
      aiAnalysisProvider: aiAnalysisProvider,
      builtInClipAnalyzerMode: builtInClipAnalyzerMode,
      ytDlpPath: normalizedYtDlpPath,
      ffmpegPath: normalizedFfmpegPath,
      aiAnalyzerCommand: normalizedAiAnalyzerCommand,
      aiCloudEndpoint: normalizedAiCloudEndpoint,
      aiCloudApiKey: normalizedAiCloudApiKey,
      aiCloudModel: normalizedAiCloudModel,
      cookieConfigs: cookieConfigs,
      defaultCookieBrowser: defaultCookieBrowser,
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
      'downloadSubtitles': downloadSubtitles,
      'downloadThumbnail': downloadThumbnail,
      'disclaimerAccepted': disclaimerAccepted,
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
    if (defaultCookieBrowser != null) {
      map['defaultCookieBrowser'] = defaultCookieBrowser!;
    }
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
    final aiAnalysisProvider = json.containsKey('aiAnalysisProvider')
        ? _parseAiAnalysisProvider(json['aiAnalysisProvider'])
        : _normalizeStaticOptionalPath(aiAnalyzerCommand) == null
        ? defaults.aiAnalysisProvider
        : AiAnalysisProvider.externalCommand;

    return DownloadSettings(
      saveDirectory:
          (json['saveDirectory'] as String?) ?? defaultSaveDirectory(),
      downloadMode: _parseDownloadMode(json['downloadMode']),
      concurrentCount:
          parseCount(json['concurrentCount']) ?? defaults.concurrentCount,
      defaultQuality:
          (json['defaultQuality'] as String?) ?? defaults.defaultQuality,
      downloadSubtitles:
          parseBool(json['downloadSubtitles']) ?? defaults.downloadSubtitles,
      downloadThumbnail:
          parseBool(json['downloadThumbnail']) ?? defaults.downloadThumbnail,
      disclaimerAccepted:
          parseBool(json['disclaimerAccepted']) ?? defaults.disclaimerAccepted,
      aiAnalysisProvider: aiAnalysisProvider,
      builtInClipAnalyzerMode: _parseBuiltInClipAnalyzerMode(
        json['builtInClipAnalyzerMode'],
      ),
      ytDlpPath: json['ytDlpPath'] as String?,
      ffmpegPath: json['ffmpegPath'] as String?,
      aiAnalyzerCommand: aiAnalyzerCommand,
      aiCloudEndpoint: json['aiCloudEndpoint'] as String?,
      aiCloudApiKey: json['aiCloudApiKey'] as String?,
      aiCloudModel: json['aiCloudModel'] as String?,
      defaultCookieBrowser: json['defaultCookieBrowser'] as String?,
    ).normalized();
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
