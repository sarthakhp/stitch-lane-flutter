import 'package:battery_plus/battery_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../backend/backend.dart';
import '../../firebase_options.dart';
import '../../utils/app_logger.dart';
import 'backup_service.dart';
import 'daily_task_scheduler.dart';
import 'drive_service.dart';
import 'image_sync_service.dart';
import 'audio_sync_service.dart';
import 'notification_service.dart';

const String autoBackupTaskName = 'com.stitchlane.autobackup';
const String autoBackupTaskTag = 'auto_backup';

class AutoBackupService {
  static final Battery _battery = Battery();
  static const _scheduler = DailyTaskScheduler(
    taskName: autoBackupTaskName,
    taskTag: autoBackupTaskTag,
  );

  static Future<void> scheduleAutoBackup(String timeString) async {
    await _scheduler.schedule(timeString);
  }

  static Future<void> cancelAutoBackup() async {
    await _scheduler.cancel();
  }

  static Future<void> scheduleTest({int delaySeconds = 15}) async {
    await _scheduler.scheduleTest(delaySeconds: delaySeconds);
  }

  static Future<void> performBackup() async {
    try {
      AppLogger.info('Starting auto-backup...');

      await _initializeForBackground();

      if (!await _checkBatteryLevel()) {
        const message = 'Battery level too low (below 15%)';
        AppLogger.warning(message);
        await NotificationService.showBackupFailedNotification(message);
        await _scheduleNextIfEnabled();
        return;
      }

      if (!await _checkDriveAccess()) {
        const message = 'Google Drive not accessible. Please sign in manually.';
        AppLogger.warning(message);
        await NotificationService.showBackupFailedNotification(message);
        await _scheduleNextIfEnabled();
        return;
      }

      await NotificationService.showBackupInProgressNotification();

      final backupJson = await BackupService.createBackup();
      await DriveService.uploadBackup(backupJson);
      await ImageSyncService.syncImagesToDrive();
      await AudioSyncService.syncAudiosToDrive();

      await _updateLastBackupTime();

      await NotificationService.showBackupSuccessNotification();

      AppLogger.info('Auto-backup completed successfully');

      await _scheduleNextIfEnabled();
    } catch (e) {
      AppLogger.error('Auto-backup failed', e);
      await NotificationService.cancelBackupInProgressNotification();
      await NotificationService.showBackupFailedNotification(
        'Backup failed: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}',
      );
      await _scheduleNextIfEnabled();
      rethrow;
    }
  }

  static Future<void> _scheduleNextIfEnabled() async {
    try {
      final settings = await _getSettings();
      if (settings.autoBackupEnabled) {
        await _scheduler.scheduleNextDay(settings.autoBackupTime);
        AppLogger.info('Next auto-backup scheduled for tomorrow');
      }
    } catch (e) {
      AppLogger.error('Failed to schedule next backup', e);
    }
  }

  static Future<AppSettings> _getSettings() async {
    final settingsBox = DatabaseService.getSettingsBox();
    return settingsBox.get('settings') ?? AppSettings();
  }

  static Future<void> _initializeForBackground() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await DatabaseService.initialize();
    await NotificationService.initialize();
  }

  static Future<bool> _checkBatteryLevel() async {
    if (kIsWeb) return true;
    try {
      final batteryLevel = await _battery.batteryLevel;
      AppLogger.info('Battery level: $batteryLevel%');
      return batteryLevel > 5;
    } catch (e) {
      AppLogger.warning('Could not check battery level: $e');
      return true;
    }
  }

  static Future<bool> _checkDriveAccess() async {
    try {
      await DriveService.getDriveApi();
      return true;
    } catch (e) {
      AppLogger.warning('Drive access check failed: $e');
      return false;
    }
  }

  static Future<void> _updateLastBackupTime() async {
    try {
      final settingsBox = DatabaseService.getSettingsBox();
      final currentSettings = settingsBox.get('settings') ?? AppSettings();
      final updatedSettings = currentSettings.copyWith(
        lastAutoBackupTime: DateTime.now(),
      );
      await settingsBox.put('settings', updatedSettings);
      AppLogger.info('Last auto-backup time updated');
    } catch (e) {
      AppLogger.error('Failed to update last backup time', e);
    }
  }

  static Future<bool> isAutoBackupEnabled() async {
    try {
      final settings = await _getSettings();
      return settings.autoBackupEnabled;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getAutoBackupTime() async {
    try {
      final settings = await _getSettings();
      return settings.autoBackupTime;
    } catch (e) {
      return '03:00';
    }
  }
}
