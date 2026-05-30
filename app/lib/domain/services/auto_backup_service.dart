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
import 'backup_time_service.dart';
import 'notification_service.dart';

const String autoBackupTaskName = 'com.stitchlane.autobackup';
const String autoBackupTaskTag = 'auto_backup';

class AutoBackupService {
  static final Battery _battery = Battery();
  static const _scheduler = DailyTaskScheduler(
    taskName: autoBackupTaskName,
    taskTag: autoBackupTaskTag,
  );

  /// Cadence between auto-backups. WAS 24h, moved to 4h because 24h was
  /// leaving too much in-flight unbacked-up data (we hit a 24h-since-backup
  /// data loss in production once). 4h on AC + WiFi is light on battery
  /// and gives a much tighter recovery window.
  static const Duration _backupInterval = Duration(hours: 4);

  /// Retry backoffs for transient failures (network blip, Drive API throttle)
  /// during the core upload. Total worst case: ~1m40s, well inside
  /// WorkManager's 10-minute task budget.
  static const List<Duration> _retryBackoffs = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
  ];

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

      final customerRepository = RepositoryFactory.createCustomerRepository();
      final orderRepository = RepositoryFactory.createOrderRepository();
      final measurementRepository = RepositoryFactory.createMeasurementRepository();
      final settingsRepository = RepositoryFactory.createSettingsRepository();

      // Safety check: verify backup is still enabled (WorkManager tasks persist
      // even after toggle is turned off)
      final settings = await settingsRepository.getSettings();
      if (!settings.autoBackupEnabled) {
        AppLogger.info('Auto-backup aborted: backup is disabled in settings');
        await cancelAutoBackup();
        return;
      }

      if (!await _checkBatteryLevel()) {
        AppLogger.warning('Battery level too low (below 15%)');
        await _scheduleNextIfEnabled(settingsRepository);
        return;
      }

      if (!await _checkDriveAccess()) {
        AppLogger.warning('Google Drive not accessible. Please sign in manually.');
        await _scheduleNextIfEnabled(settingsRepository);
        return;
      }

      await NotificationService.showBackupInProgressNotification();

      // Core backup: JSON data upload. Wrapped in retry-with-backoff so a
      // transient network blip or Drive API throttle doesn't get reported
      // as a hard failure on the BackupHealthCard. Up to 3 retries with
      // 10s/30s/1m delays — total max ~1m40s, well under WorkManager's
      // 10-minute task budget.
      await _retryWithBackoff(
        label: 'Auto-backup core upload',
        task: () async {
          final backupJson = await BackupService.createBackup(
            customerRepository: customerRepository,
            orderRepository: orderRepository,
            measurementRepository: measurementRepository,
            settingsRepository: settingsRepository,
          );
          await DriveService.uploadBackup(backupJson);
        },
      );

      // File sync: image + audio (if these fail, it's a partial backup)
      final syncErrors = <String>[];
      try {
        await ImageSyncService.syncImagesToDrive(orderRepository: orderRepository);
      } catch (e) {
        syncErrors.add('Images: $e');
        AppLogger.error('Auto-backup: image sync failed', e);
      }
      try {
        await AudioSyncService.syncAudiosToDrive();
      } catch (e) {
        syncErrors.add('Audio: $e');
        AppLogger.error('Auto-backup: audio sync failed', e);
      }

      if (syncErrors.isEmpty) {
        await BackupTimeService.recordSuccess(settingsRepository: settingsRepository);
        await NotificationService.showBackupSuccessNotification();
        AppLogger.info('Auto-backup completed successfully');
      } else {
        await BackupTimeService.recordPartial(
          settingsRepository: settingsRepository,
          error: syncErrors.join('; '),
        );
        await NotificationService.showBackupPartialNotification();
        AppLogger.warning('Auto-backup completed with errors: ${syncErrors.join('; ')}');
      }

      await _scheduleNextIfEnabled(settingsRepository);
    } catch (e) {
      AppLogger.error('Auto-backup failed', e);
      await NotificationService.cancelBackupInProgressNotification();
      try {
        final settingsRepository = RepositoryFactory.createSettingsRepository();
        await BackupTimeService.recordFailed(
          settingsRepository: settingsRepository,
          error: e.toString(),
        );
        await NotificationService.showBackupFailedNotification(e.toString());
        await _scheduleNextIfEnabled(settingsRepository);
      } catch (statusError) {
        AppLogger.error('Failed to record backup failure', statusError);
      }
      rethrow;
    }
  }

  static Future<void> _scheduleNextIfEnabled(SettingsRepository settingsRepository) async {
    try {
      final settings = await settingsRepository.getSettings();
      if (settings.autoBackupEnabled) {
        await _scheduler.scheduleAfter(_backupInterval);
        AppLogger.info(
          'Next auto-backup scheduled in ${_backupInterval.inHours}h',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to schedule next backup', e);
    }
  }

  /// Runs [task] with bounded retries on failure. Used by [performBackup] to
  /// shrug off transient errors (network blip, Drive throttle) without
  /// promoting them to a "Backup failed" status that pages the user.
  ///
  /// Returns the task's result on success. Rethrows the LAST exception if
  /// every attempt fails — the caller (performBackup) records that as a
  /// hard failure.
  static Future<T> _retryWithBackoff<T>({
    required String label,
    required Future<T> Function() task,
  }) async {
    final maxAttempts = _retryBackoffs.length + 1;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await task();
      } catch (e, st) {
        if (attempt == maxAttempts) {
          AppLogger.error(
            '$label: all $maxAttempts attempts failed',
            e,
            st,
          );
          rethrow;
        }
        final delay = _retryBackoffs[attempt - 1];
        AppLogger.warning(
          '$label: attempt $attempt/$maxAttempts failed ($e) — retrying in ${delay.inSeconds}s',
        );
        await Future.delayed(delay);
      }
    }
    // Unreachable — loop either returns or rethrows. Required for type system.
    throw StateError('_retryWithBackoff: exited loop without resolving');
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

  static Future<bool> isAutoBackupEnabled() async {
    try {
      final settingsRepository = RepositoryFactory.createSettingsRepository();
      final settings = await settingsRepository.getSettings();
      return settings.autoBackupEnabled;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getAutoBackupTime() async {
    try {
      final settingsRepository = RepositoryFactory.createSettingsRepository();
      final settings = await settingsRepository.getSettings();
      return settings.autoBackupTime;
    } catch (e) {
      return '03:00';
    }
  }
}
