import '../../backend/repositories/settings_repository.dart';
import '../../backend/models/app_settings.dart';
import '../state/settings_state.dart';

class SettingsService {
  static Future<void> loadSettings(
    SettingsState state,
    SettingsRepository repository,
  ) async {
    state.setLoading(true);
    state.setError(null);

    try {
      final settings = await repository.getSettings();
      state.setSettings(settings);
    } catch (e) {
      state.setError('Failed to load settings: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> updateSettings(
    SettingsState state,
    SettingsRepository repository,
    AppSettings settings,
  ) async {
    state.setLoading(true);
    state.setError(null);

    try {
      await repository.saveSettings(settings);
      state.setSettings(settings);
    } catch (e) {
      state.setError('Failed to save settings: $e');
    } finally {
      state.setLoading(false);
    }
  }
}

