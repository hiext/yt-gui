enum YtDlpProgressEventType { progress, info, error }

class YtDlpProgressEvent {
  const YtDlpProgressEvent({
    required this.type,
    this.stage,
    this.percent,
    this.speed,
    this.eta,
    this.message,
  });

  final YtDlpProgressEventType type;
  final String? stage;
  final double? percent;
  final String? speed;
  final String? eta;
  final String? message;
}

class YtDlpProgressParser {
  const YtDlpProgressParser._();

  static YtDlpProgressEvent? parse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final progressMatch = RegExp(
      r'^\[(?<stage>[^\]]+)\]\s+(?<percent>\d+(?:\.\d+)?)%.*?at\s+(?<speed>\S+)\s+ETA\s+(?<eta>\S+)',
    ).firstMatch(trimmed);
    if (progressMatch != null) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.progress,
        stage: progressMatch.namedGroup('stage'),
        percent: double.tryParse(progressMatch.namedGroup('percent') ?? ''),
        speed: progressMatch.namedGroup('speed'),
        eta: progressMatch.namedGroup('eta'),
      );
    }

    if (trimmed.startsWith('ERROR:')) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.error,
        message: trimmed.substring('ERROR:'.length).trim(),
      );
    }

    final infoMatch = RegExp(
      r'^\[(?<level>info|warning|debug)\]\s+(?<message>.+)$',
    ).firstMatch(trimmed);
    if (infoMatch != null) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.info,
        message: infoMatch.namedGroup('message'),
      );
    }

    return null;
  }
}
