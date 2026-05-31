import '../models/app_models.dart';
import 'database_service.dart';

class SettingsRepository {
  Future<DownloadSettings> load() async {
    final data = await DatabaseService().loadSettings();
    if (data.isEmpty) {
      final defaults = DownloadSettings.defaults.normalized();
      // Persist defaults on first launch so DB has full config
      await DatabaseService().saveSettings(defaults.toJson());
      return defaults;
    }
    return DownloadSettings.fromJson(data);
  }

  Future<void> save(DownloadSettings settings) async {
    await DatabaseService().saveSettings(settings.normalized().toJson());
  }

  void dispose() {}
}
