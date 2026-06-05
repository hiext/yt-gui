import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../models/app_models.dart';
import '../services/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    DownloadSettings settings = DownloadSettings.defaults,
    this.repository,
  }) : _settings = settings.normalized(),
       _hasLoaded = repository == null;

  final SettingsRepository? repository;

  DownloadSettings _settings;
  bool _hasLoaded;

  DownloadSettings get settings => _settings;
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    final loaded = await repository?.load();
    if (loaded != null) {
      _settings = loaded.normalized();
    }
    _hasLoaded = true;
    notifyListeners();
  }

  void updateSettings(DownloadSettings settings) {
    _settings = settings.normalized();
    _save();
    notifyListeners();
  }

  void updateSaveDirectory(String saveDirectory) {
    updateSettings(_settings.copyWith(saveDirectory: saveDirectory));
  }

  void updateDownloadMode(DownloadMode downloadMode) {
    updateSettings(_settings.copyWith(downloadMode: downloadMode));
  }

  void updateConcurrentCount(int concurrentCount) {
    updateSettings(_settings.copyWith(concurrentCount: concurrentCount));
  }

  void updateDefaultQuality(String defaultQuality) {
    updateSettings(_settings.copyWith(defaultQuality: defaultQuality));
  }

  void updateDownloadSubtitles(bool downloadSubtitles) {
    updateSettings(_settings.copyWith(downloadSubtitles: downloadSubtitles));
  }

  void updateDownloadThumbnail(bool downloadThumbnail) {
    updateSettings(_settings.copyWith(downloadThumbnail: downloadThumbnail));
  }

  void acknowledgeDisclaimer() {
    updateSettings(_settings.copyWith(disclaimerAccepted: true));
  }

  void updateYtDlpPath(String ytDlpPath) {
    updateSettings(_settings.copyWith(ytDlpPath: ytDlpPath));
  }

  void updateFfmpegPath(String ffmpegPath) {
    updateSettings(_settings.copyWith(ffmpegPath: ffmpegPath));
  }

  void updateAiAnalyzerCommand(String command) {
    updateSettings(_settings.copyWith(aiAnalyzerCommand: command));
  }

  void _save() {
    final repo = repository;
    if (repo == null) return;
    unawaited(
      repo.save(_settings).onError((error, stackTrace) {
        debugPrint('Failed to persist settings: $error');
      }),
    );
  }
}
