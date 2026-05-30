import 'dart:io';

enum DownloadMode { serial, queue, concurrent }

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
    this.ytDlpPath,
    this.ffmpegPath,
  });

  static const defaults = DownloadSettings(
    saveDirectory: '',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
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
  final String? ytDlpPath;
  final String? ffmpegPath;

  DownloadSettings copyWith({
    String? saveDirectory,
    DownloadMode? downloadMode,
    int? concurrentCount,
    String? defaultQuality,
    bool? downloadSubtitles,
    bool? downloadThumbnail,
    Object? ytDlpPath = _unchanged,
    Object? ffmpegPath = _unchanged,
  }) {
    return DownloadSettings(
      saveDirectory: saveDirectory ?? this.saveDirectory,
      downloadMode: downloadMode ?? this.downloadMode,
      concurrentCount: concurrentCount ?? this.concurrentCount,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      downloadThumbnail: downloadThumbnail ?? this.downloadThumbnail,
      ytDlpPath: ytDlpPath == _unchanged
          ? this.ytDlpPath
          : ytDlpPath as String?,
      ffmpegPath: ffmpegPath == _unchanged
          ? this.ffmpegPath
          : ffmpegPath as String?,
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

    return DownloadSettings(
      saveDirectory: normalizedSaveDirectory,
      downloadMode: downloadMode,
      concurrentCount: concurrentCount.clamp(1, 8).toInt(),
      defaultQuality: normalizedDefaultQuality,
      downloadSubtitles: downloadSubtitles,
      downloadThumbnail: downloadThumbnail,
      ytDlpPath: normalizedYtDlpPath,
      ffmpegPath: normalizedFfmpegPath,
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
    };
    if (ytDlpPath != null) map['ytDlpPath'] = ytDlpPath!;
    if (ffmpegPath != null) map['ffmpegPath'] = ffmpegPath!;
    return map;
  }

  factory DownloadSettings.fromJson(Map<String, Object?> json) {
    return DownloadSettings(
      saveDirectory:
          (json['saveDirectory'] as String?) ?? defaultSaveDirectory(),
      downloadMode: _parseDownloadMode(json['downloadMode']),
      concurrentCount:
          (json['concurrentCount'] as int?) ?? defaults.concurrentCount,
      defaultQuality:
          (json['defaultQuality'] as String?) ?? defaults.defaultQuality,
      downloadSubtitles:
          (json['downloadSubtitles'] as bool?) ?? defaults.downloadSubtitles,
      downloadThumbnail:
          (json['downloadThumbnail'] as bool?) ?? defaults.downloadThumbnail,
      ytDlpPath: json['ytDlpPath'] as String?,
      ffmpegPath: json['ffmpegPath'] as String?,
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

  DownloadTask copyWith({
    DownloadStatus? status,
    double? progress,
    Object? errorMessage = _unchanged,
    Object? speed = _unchanged,
    Object? eta = _unchanged,
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
    );
  }
}
