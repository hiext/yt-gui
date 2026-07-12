import '../models/license_models.dart';
import 'database_service.dart';

/// Loads and persists local license state via the single-row `license_state`
/// table. Kept separate from settings so the full-overwrite settings save
/// never clobbers license data.
class LicenseRepository {
  Future<LicenseState> load() async {
    final raw = await DatabaseService().loadLicense();
    if (raw == null || raw.trim().isEmpty) return LicenseState.free;
    try {
      return LicenseState.decode(raw);
    } catch (_) {
      return LicenseState.free;
    }
  }

  Future<void> save(LicenseState state) async {
    await DatabaseService().saveLicense(state.encode());
  }

  void dispose() {}
}
