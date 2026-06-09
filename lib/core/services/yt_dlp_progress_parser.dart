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

  static const _templateMarker = '__HIEYT_PROGRESS__:';

  /// Matches yt-dlp default progress output:
  ///   [download]   5.2% of ~100.00MiB at  2.50MiB/s ETA 00:38
  ///   [download]   0.1% of  261.91MiB at  Unknown B/s ETA Unknown
  ///   [download]   0.7% of ~18.40GiB   (no speed/ETA)
  static final _progressRe = RegExp(
    r'^\[(?<stage>[^\]]+)\]\s+'
    r'(?<percent>\d+(?:\.\d+)?)%\s+of\s+'
    r'~?(?<total>[\d.]+[KMG]?iB)'
    r'(?:\s+at\s+'
    r'(?<speed>(?:\d+(?:\.\d+)?\s*(?:[KMG]iB|B)/s)|Unknown B/s))?'
    r'(?:\s+ETA\s+(?<eta>[\d:]+|Unknown))?',
  );

  /// Matches yt-dlp info/warning lines:
  ///   [info] Available formats: ...
  ///   [warning] ...
  static final _infoRe = RegExp(
    r'^\[(?<level>info|warning|debug)\]\s+(?<message>.+)$',
  );

  /// Matches yt-dlp error lines:
  ///   ERROR: Unable to download webpage: HTTP Error 403: Forbidden
  ///   ERROR: [BiliBili] 1gU5Y6SE38: Video unavailable
  static final _errorRe = RegExp(
    r'^(?:.*:\s+)?(?:ERROR|Error):\s+(?<message>.+)$',
  );

  /// Matches the custom template prefix (kept for backward compatibility).
  ///   __HIEYT_PROGRESS__:downloading|42.5%|3.45MiB/s|00:18
  static final _templateRe = RegExp(
    r'^__HIEYT_PROGRESS__:'
    r'(?<stage>[^|]*)\|'
    r'\s*(?<percent>[\d.]+%?)\s*\|'
    r'\s*(?<speed>[^|]*?)\s*\|'
    r'\s*(?<eta>[^|]*?)\s*$',
  );

  static YtDlpProgressEvent? parse(String line) {
    final trimmed = line
        .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
        .trim();
    if (trimmed.isEmpty) return null;

    // 1. Default yt-dlp progress format (regex)
    final progressMatch = _progressRe.firstMatch(trimmed);
    if (progressMatch != null) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.progress,
        stage: progressMatch.namedGroup('stage'),
        percent: double.tryParse(progressMatch.namedGroup('percent') ?? ''),
        speed: _normalizeField(progressMatch.namedGroup('speed')),
        eta: _normalizeField(progressMatch.namedGroup('eta')),
      );
    }

    // 2. Custom template format. yt-dlp may prepend log fragments around
    // --progress-template output, so extract from the marker instead of
    // requiring it at the beginning of the line.
    final templateIndex = trimmed.indexOf(_templateMarker);
    final templateLine = templateIndex >= 0
        ? trimmed.substring(templateIndex)
        : trimmed;
    final templateMatch = _templateRe.firstMatch(templateLine);
    if (templateMatch != null) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.progress,
        stage: _normalizeField(templateMatch.namedGroup('stage') ?? ''),
        percent: _parsePercent(templateMatch.namedGroup('percent') ?? ''),
        speed: _normalizeField(templateMatch.namedGroup('speed')),
        eta: _normalizeField(templateMatch.namedGroup('eta')),
      );
    }

    // 3. Error lines (regex)
    final errorMatch = _errorRe.firstMatch(trimmed);
    if (errorMatch != null) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.error,
        message: errorMatch.namedGroup('message')?.trim(),
      );
    }

    // 4. Info/warning lines (regex)
    final infoMatch = _infoRe.firstMatch(trimmed);
    if (infoMatch != null) {
      return YtDlpProgressEvent(
        type: YtDlpProgressEventType.info,
        message: infoMatch.namedGroup('message'),
      );
    }

    return null;
  }

  static double? _parsePercent(String value) {
    final normalized = value.replaceAll('%', '').trim();
    return double.tryParse(normalized);
  }

  static String? _normalizeField(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized == 'NA' ||
        normalized.toLowerCase().startsWith('unknown')) {
      return null;
    }
    return normalized;
  }
}
