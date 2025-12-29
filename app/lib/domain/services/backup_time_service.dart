import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';

class BackupTimeService {
  static Future<void> updateLastBackupTime() async {
    try {
      final settingsBox = DatabaseService.getSettingsBox();
      final currentSettings = settingsBox.get(AppConstants.settingsKey) ?? AppSettings();
      final updatedSettings = currentSettings.copyWith(
        lastBackupTime: DateTime.now(),
      );
      await settingsBox.put(AppConstants.settingsKey, updatedSettings);
      AppLogger.info('Last backup time updated');
    } catch (e) {
      AppLogger.error('Failed to update last backup time', e);
    }
  }
}

