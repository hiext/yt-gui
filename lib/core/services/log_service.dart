import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.source,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? source;
}

class LogService extends ChangeNotifier {
  LogService._();

  static final LogService _instance = LogService._();

  static LogService get instance => _instance;

  LogLevel _level = LogLevel.debug;
  final List<LogEntry> _entries = [];
  static const int _maxEntries = 2000;

  LogLevel get level => _level;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void setLevel(LogLevel level) {
    _level = level;
    notifyListeners();
  }

  void _add(LogLevel level, String message, [String? source]) {
    if (level.index < _level.index) return;

    _entries.add(
      LogEntry(
        timestamp: DateTime.now(),
        level: level,
        message: message,
        source: source,
      ),
    );
    // Trim old entries
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    notifyListeners();
  }

  void debug(String message, [String? source]) =>
      _add(LogLevel.debug, message, source);

  void info(String message, [String? source]) =>
      _add(LogLevel.info, message, source);

  void warn(String message, [String? source]) =>
      _add(LogLevel.warning, message, source);

  void error(String message, [String? source]) =>
      _add(LogLevel.error, message, source);

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
