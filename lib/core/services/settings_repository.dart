import '../models/app_models.dart';
import 'database_service.dart';

class SettingsRepository {
  Future<DownloadSettings> load() async {
    final data = await DatabaseService().loadSettings();
    if (data.isEmpty) return DownloadSettings.defaults.normalized();
    return DownloadSettings.fromJson(data);
  }

  Future<void> save(DownloadSettings settings) async {
    await DatabaseService().saveSettings(settings.normalized().toJson());
  }

  void dispose() {}
}
