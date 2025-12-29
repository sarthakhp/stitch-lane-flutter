import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import 'app_lifecycle_backup_service.dart';
import 'auto_backup_service.dart';

class StartupBackupChecker {
  static Duration get _backupThreshold => AppLifecycleBackupService.backupThreshold;

  static Future<void> checkAndPerformBackupIfNeeded({
    void Function()? onBackupComplete,
  }) async {
    try {
      final settings = await _getSettings();

      if (!settings.autoBackupEnabled) {
        AppLogger.info('StartupBackupChecker: Auto backup is disabled');
        return;
      }

      if (!_isBackupOverdue(settings.lastBackupTime)) {
        AppLogger.info('StartupBackupChecker: Last backup is within threshold');
        return;
      }

      AppLogger.info('StartupBackupChecker: Backup is overdue, triggering backup');
      await AutoBackupService.performBackup();
      onBackupComplete?.call();
    } catch (e) {
      AppLogger.error('StartupBackupChecker: Failed to check/perform backup', e);
    }
  }

  static bool _isBackupOverdue(DateTime? lastBackupTime) {
    if (lastBackupTime == null) {
      return true;
    }

    final timeSinceLastBackup = DateTime.now().difference(lastBackupTime);
    return timeSinceLastBackup > _backupThreshold;
  }

  static Future<AppSettings> _getSettings() async {
    final settingsBox = DatabaseService.getSettingsBox();
    return settingsBox.get(AppConstants.settingsKey) ?? AppSettings();
  }
}

