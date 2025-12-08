import 'package:hive/hive.dart';
import '../models/app_settings.dart';
import '../database/database_service.dart';
import 'settings_repository.dart';

class HiveSettingsRepository implements SettingsRepository {
  static const String _settingsKey = 'app_settings';
  
  Box<AppSettings> get _box => DatabaseService.getSettingsBox();

  @override
  Future<AppSettings> getSettings() async {
    try {
      final settings = _box.get(_settingsKey);
      return settings ?? AppSettings();
    } catch (e) {
      throw Exception('Failed to get settings: $e');
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      await _box.put(_settingsKey, settings);
    } catch (e) {
      throw Exception('Failed to save settings: $e');
    }
  }
}

