import 'package:flutter/widgets.dart';
import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import 'auto_backup_service.dart';
import 'drive_service.dart';

class AppLifecycleBackupService with WidgetsBindingObserver {
  static const Duration backupThreshold = Duration(hours: 1);

  bool _isBackupInProgress = false;
  bool _isInitialized = false;
  VoidCallback? _onBackupComplete;

  void initialize({VoidCallback? onBackupComplete}) {
    if (_isInitialized) return;

    _onBackupComplete = onBackupComplete;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    AppLogger.info('AppLifecycleBackupService: Initialized');
  }

  void dispose() {
    if (!_isInitialized) return;

    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
    _onBackupComplete = null;
    AppLogger.info('AppLifecycleBackupService: Disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppLogger.info('AppLifecycleBackupService: App resumed');
      _checkAndPerformBackupIfNeeded();
    }
  }

  Future<void> _checkAndPerformBackupIfNeeded() async {
    if (_isBackupInProgress) {
      AppLogger.info('AppLifecycleBackupService: Backup already in progress, skipping');
      return;
    }

    try {
      _isBackupInProgress = true;

      final settings = await _getSettings();

      if (!settings.autoBackupEnabled) {
        AppLogger.info('AppLifecycleBackupService: Auto backup is disabled');
        return;
      }

      if (!await _isDriveSignedIn()) {
        AppLogger.info('AppLifecycleBackupService: Not signed in to Google Drive');
        return;
      }

      if (!_isBackupOverdue(settings.lastBackupTime)) {
        AppLogger.info('AppLifecycleBackupService: Last backup is within threshold');
        return;
      }

      AppLogger.info('AppLifecycleBackupService: Backup is overdue, triggering backup');
      await AutoBackupService.performBackup();
      _onBackupComplete?.call();
    } catch (e) {
      AppLogger.error('AppLifecycleBackupService: Failed to check/perform backup', e);
    } finally {
      _isBackupInProgress = false;
    }
  }

  Future<void> checkOnStartup() async {
    await _checkAndPerformBackupIfNeeded();
  }

  static bool _isBackupOverdue(DateTime? lastBackupTime) {
    if (lastBackupTime == null) {
      return true;
    }

    final timeSinceLastBackup = DateTime.now().difference(lastBackupTime);
    return timeSinceLastBackup > backupThreshold;
  }

  Future<AppSettings> _getSettings() async {
    final settingsBox = DatabaseService.getSettingsBox();
    return settingsBox.get(AppConstants.settingsKey) ?? AppSettings();
  }

  Future<bool> _isDriveSignedIn() async {
    try {
      return await DriveService.isSignedIn();
    } catch (e) {
      return false;
    }
  }
}

