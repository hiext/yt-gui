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
  });

  static const defaults = DownloadSettings(
    saveDirectory: '.',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
  );

  final String saveDirectory;
  final DownloadMode downloadMode;
  final int concurrentCount;
  final String defaultQuality;
  final bool downloadSubtitles;
  final bool downloadThumbnail;

  DownloadSettings copyWith({
    String? saveDirectory,
    DownloadMode? downloadMode,
    int? concurrentCount,
    String? defaultQuality,
    bool? downloadSubtitles,
    bool? downloadThumbnail,
  }) {
    return DownloadSettings(
      saveDirectory: saveDirectory ?? this.saveDirectory,
      downloadMode: downloadMode ?? this.downloadMode,
      concurrentCount: concurrentCount ?? this.concurrentCount,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      downloadSubtitles: downloadSubtitles ?? this.downloadSubtitles,
      downloadThumbnail: downloadThumbnail ?? this.downloadThumbnail,
    ).normalized();
  }

  DownloadSettings normalized() {
    final normalizedSaveDirectory = saveDirectory.trim().isEmpty
        ? defaults.saveDirectory
        : saveDirectory.trim();
    final normalizedDefaultQuality = defaultQuality.trim().isEmpty
        ? defaults.defaultQuality
        : defaultQuality.trim();

    return DownloadSettings(
      saveDirectory: normalizedSaveDirectory,
      downloadMode: downloadMode,
      concurrentCount: concurrentCount.clamp(1, 8).toInt(),
      defaultQuality: normalizedDefaultQuality,
      downloadSubtitles: downloadSubtitles,
      downloadThumbnail: downloadThumbnail,
    );
  }
}

class ResourceVariant {
  const ResourceVariant({
    required this.label,
    required this.description,
    required this.isRecommended,
    this.formatId,
  });

  final String label;
  final String description;
  final bool isRecommended;
  final String? formatId;
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
}
