import '../../backend/backend.dart';
import '../../utils/app_logger.dart';

class BackupTimeService {
  static Future<void> updateLastBackupTime({
    required SettingsRepository settingsRepository,
  }) async {
    try {
      final currentSettings = await settingsRepository.getSettings();
      final updatedSettings = currentSettings.copyWith(
        lastBackupTime: DateTime.now(),
      );
      await settingsRepository.saveSettings(updatedSettings);
      AppLogger.info('Last backup time updated');
    } catch (e) {
      AppLogger.error('Failed to update last backup time', e);
    }
  }
}
