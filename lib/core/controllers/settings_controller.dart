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

  void updateAiAnalysisProvider(AiAnalysisProvider provider) {
    updateSettings(_settings.copyWith(aiAnalysisProvider: provider));
  }

  void updateBuiltInClipAnalyzerMode(BuiltInClipAnalyzerMode mode) {
    updateSettings(_settings.copyWith(builtInClipAnalyzerMode: mode));
  }

  void updateAiAnalyzerCommand(String command) {
    updateSettings(_settings.copyWith(aiAnalyzerCommand: command));
  }

  void addAiCloudConfig(AiCloudVendor vendor) {
    final id = _uniqueAiCloudConfigId(vendor);
    final config = AiCloudConfig.preset(vendor, id: id);
    updateSettings(
      _settings.copyWith(
        aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
        selectedAiCloudConfigId: config.id,
        aiCloudConfigs: [..._settings.aiCloudConfigs, config],
      ),
    );
  }

  void updateSelectedAiCloudConfig(String id) {
    updateSettings(_settings.copyWith(selectedAiCloudConfigId: id));
  }

  void removeAiCloudConfig(String id) {
    final configs = _settings.aiCloudConfigs
        .where((config) => config.id != id)
        .toList();
    final selectedId = configs.isEmpty ? null : configs.first.id;
    updateSettings(
      _settings.copyWith(
        selectedAiCloudConfigId: selectedId,
        aiCloudConfigs: configs,
      ),
    );
  }

  void updateSelectedAiCloudVendor(AiCloudVendor vendor) {
    final current = _ensureSelectedAiCloudConfig(vendor);
    final preset = AiCloudConfig.preset(vendor, id: current.id);
    _upsertAiCloudConfig(
      preset.copyWith(apiKey: current.apiKey, enabled: current.enabled),
    );
  }

  void updateSelectedAiCloudName(String name) {
    final current = _ensureSelectedAiCloudConfig(AiCloudVendor.custom);
    _upsertAiCloudConfig(current.copyWith(name: name));
  }

  void updateAiCloudEndpoint(String endpoint) {
    final current = _ensureSelectedAiCloudConfig(AiCloudVendor.custom);
    _upsertAiCloudConfig(current.copyWith(endpoint: endpoint));
  }

  void updateAiCloudApiKey(String apiKey) {
    final current = _ensureSelectedAiCloudConfig(AiCloudVendor.custom);
    _upsertAiCloudConfig(current.copyWith(apiKey: apiKey));
  }

  void updateAiCloudModel(String model) {
    final current = _ensureSelectedAiCloudConfig(AiCloudVendor.custom);
    _upsertAiCloudConfig(current.copyWith(model: model));
  }

  AiCloudConfig _ensureSelectedAiCloudConfig(AiCloudVendor fallbackVendor) {
    final selected = _settings.selectedAiCloudConfig;
    if (selected != null) return selected;
    return AiCloudConfig.preset(
      fallbackVendor,
      id: _uniqueAiCloudConfigId(fallbackVendor),
    );
  }

  void _upsertAiCloudConfig(AiCloudConfig config) {
    var replaced = false;
    final configs = _settings.aiCloudConfigs.map((item) {
      if (item.id != config.id) return item;
      replaced = true;
      return config;
    }).toList();
    if (!replaced) {
      configs.add(config);
    }
    updateSettings(
      _settings.copyWith(
        aiAnalysisProvider: AiAnalysisProvider.cloudEndpoint,
        selectedAiCloudConfigId: config.id,
        aiCloudConfigs: configs,
      ),
    );
  }

  String _uniqueAiCloudConfigId(AiCloudVendor vendor) {
    final existingIds = _settings.aiCloudConfigs
        .map((config) => config.id)
        .toSet();
    final base = vendor.name;
    if (!existingIds.contains(base)) return base;
    for (var index = 2; index < 100; index += 1) {
      final candidate = '$base$index';
      if (!existingIds.contains(candidate)) return candidate;
    }
    return '$base${DateTime.now().millisecondsSinceEpoch}';
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
