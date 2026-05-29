import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({DownloadSettings settings = DownloadSettings.defaults})
    : _settings = settings.normalized();

  DownloadSettings _settings;

  DownloadSettings get settings => _settings;

  void updateSettings(DownloadSettings settings) {
    _settings = settings.normalized();
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
}
