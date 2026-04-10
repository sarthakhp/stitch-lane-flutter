import '../../backend/backend.dart';
import '../../utils/app_logger.dart';

class BackupTimeService {
  /// Record a fully successful backup. Updates lastBackupTime + clears error.
  static Future<void> recordSuccess({
    required SettingsRepository settingsRepository,
  }) async {
    try {
      final current = await settingsRepository.getSettings();
      await settingsRepository.saveSettings(current.copyWith(
        lastBackupTime: DateTime.now(),
        lastBackupStatus: 'success',
        lastBackupError: '',
      ));
      AppLogger.info('Backup status: success');
    } catch (e) {
      AppLogger.error('Failed to record backup success', e);
    }
  }

  /// Record a partial backup (data saved, but some files failed).
  /// Does NOT update lastBackupTime — that only moves forward on full success.
  static Future<void> recordPartial({
    required SettingsRepository settingsRepository,
    required String error,
  }) async {
    try {
      final current = await settingsRepository.getSettings();
      await settingsRepository.saveSettings(current.copyWith(
        lastBackupStatus: 'partial',
        lastBackupError: error,
      ));
      AppLogger.warning('Backup status: partial — $error');
    } catch (e) {
      AppLogger.error('Failed to record partial backup', e);
    }
  }

  /// Record a completely failed backup.
  /// Does NOT update lastBackupTime.
  static Future<void> recordFailed({
    required SettingsRepository settingsRepository,
    required String error,
  }) async {
    try {
      final current = await settingsRepository.getSettings();
      await settingsRepository.saveSettings(current.copyWith(
        lastBackupStatus: 'failed',
        lastBackupError: error,
      ));
      AppLogger.error('Backup status: failed — $error');
    } catch (e) {
      AppLogger.error('Failed to record backup failure', e);
    }
  }

  /// Legacy method — kept for backward compatibility, calls recordSuccess.
  static Future<void> updateLastBackupTime({
    required SettingsRepository settingsRepository,
  }) async {
    await recordSuccess(settingsRepository: settingsRepository);
  }
}
