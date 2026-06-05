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

  static const progressPrefix = '__HIEYT_PROGRESS__:';

  static YtDlpProgressEvent? parse(String line) {
    final trimmed = line
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith(progressPrefix)) {
      return _parseTemplateProgress(trimmed.substring(progressPrefix.length));
    }

    final progressMatch = RegExp(
      r'^\[(?<stage>[^\]]+)\]\s+(?<percent>\d+(?:\.\d+)?)%',
    ).firstMatch(trimmed);
    if (progressMatch != null) {
      final suffix = trimmed.substring(progressMatch.end);
      final speedMatch = RegExp(
        r'\sat\s+(?<speed>.+?)(?:\s+ETA\s+(?<eta>.+?))?\s*$',
      ).firstMatch(suffix);
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.progress,
        stage: progressMatch.namedGroup('stage'),
        percent: double.tryParse(progressMatch.namedGroup('percent') ?? ''),
        speed: speedMatch?.namedGroup('speed')?.trim(),
        eta: speedMatch?.namedGroup('eta')?.trim(),
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

  static YtDlpProgressEvent? _parseTemplateProgress(String payload) {
    final fields = payload.split('|');
    if (fields.length < 4) {
      return null;
    }

    final stage = _normalizeField(fields[0]);
    final percent = _parsePercent(fields[1]);
    if (percent == null) {
      return null;
    }

    return YtDlpProgressEvent(
      type: YtDlpProgressEventType.progress,
      stage: stage ?? 'download',
      percent: percent,
      speed: _normalizeField(fields[2]),
      eta: _normalizeField(fields[3]),
    );
  }

  static double? _parsePercent(String value) {
    final normalized = value.replaceAll('%', '').trim();
    return double.tryParse(normalized);
  }

  static String? _normalizeField(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == 'NA') {
      return null;
    }
    return normalized;
  }
}
