import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backend/backend.dart';
import '../domain/domain.dart';
import '../domain/services/sync/sync_drive_authority.dart';
import 'widgets/confirmation_dialog.dart';

/// The user-facing "Back up now" flow, shared by the Settings backup button
/// and the home [BackupHealthCard] so both behave identically:
///
///   confirmation dialog -> create backup -> upload to Drive
///   -> sync images -> sync audio -> record status -> reload settings -> snackbar
///
/// This is the FOREGROUND path (BackupService + DriveService directly), which
/// is deliberately distinct from `AutoBackupService.performBackup()` — that one
/// is the WorkManager/background path with battery + Drive-access guards that
/// silently no-op when invoked from the foreground (which is why wiring the
/// card to it made the button appear to "do nothing").
///
/// Returns true if a backup completed (fully or partially), false if the user
/// cancelled or it failed. Progress/error state flows through [BackupState];
/// [SettingsState] is reloaded at the end so the freshness indicator on the
/// home card updates immediately.
Future<bool> runManualBackup(BuildContext context) async {
  // Only the writer (or a sole-owner with sync off) owns the cloud backup. A
  // reader is a derived replica — let it back up and it would clobber the
  // writer's authoritative copy. UI hides the entry points for readers; this is
  // the shared last-line guard so neither the home card nor Settings can slip
  // through. Checked first so a reader never even sees the confirm dialog.
  if (!await SyncDriveAuthority.canWriteDrive()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This device syncs from the primary device, which manages backups. '
            'Back up from there instead.',
          ),
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;

  final confirmed = await ConfirmationDialog.show(
    context: context,
    title: 'Backup to Google Drive',
    content:
        'This will backup all your data (customers, orders, settings) to Google Drive. Any existing backup will be replaced.',
    confirmText: 'Backup',
  );
  if (!confirmed || !context.mounted) return false;

  final backupState = context.read<BackupState>();
  final customerRepository = context.read<CustomerRepository>();
  final orderRepository = context.read<OrderRepository>();
  final measurementRepository = context.read<MeasurementRepository>();
  final settingsRepository = context.read<SettingsRepository>();
  final measurementFieldRepository = context.read<MeasurementFieldRepository>();
  final settingsState = context.read<SettingsState>();

  try {
    backupState.setLoading(true);
    backupState.setProgress(0.2);

    final backupJson = await BackupService.createBackup(
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      measurementRepository: measurementRepository,
      settingsRepository: settingsRepository,
      measurementFieldRepository: measurementFieldRepository,
    );

    // Safeguard: never overwrite the cloud backup with an empty dataset (e.g.
    // a fresh sign-in before data has synced). Nudge the user instead of
    // silently replacing their good backup with nothing.
    if (BackupGuard.isEmptyBackupJson(backupJson)) {
      backupState.setLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nothing to back up yet — add a customer or order first. '
              'Your existing backup is safe.',
            ),
          ),
        );
      }
      return false;
    }

    backupState.setProgress(0.4);
    await DriveService.uploadBackup(backupJson);

    // Image + audio sync are non-fatal: failures here downgrade the result to
    // "partial" rather than aborting the whole backup.
    final syncErrors = <String>[];
    backupState.setDetailedProgress(0.5, 'Syncing images...');
    try {
      await ImageSyncService.syncImagesToDrive(
        orderRepository: orderRepository,
        onProgress: (current, total, message) {
          final fraction = 0.5 + (current / total) * 0.2;
          backupState.setDetailedProgress(fraction, message);
        },
      );
    } catch (e) {
      syncErrors.add('Images: $e');
    }
    backupState.setDetailedProgress(0.7, 'Syncing audio...');
    try {
      await AudioSyncService.syncAudiosToDrive(
        onProgress: (current, total, message) {
          final fraction = 0.7 + (current / total) * 0.2;
          backupState.setDetailedProgress(fraction, message);
        },
      );
    } catch (e) {
      syncErrors.add('Audio: $e');
    }

    backupState.setProgress(0.9);
    if (syncErrors.isEmpty) {
      await BackupTimeService.recordSuccess(
          settingsRepository: settingsRepository);
    } else {
      await BackupTimeService.recordPartial(
        settingsRepository: settingsRepository,
        error: syncErrors.join('; '),
      );
    }

    final backupInfo = await DriveService.getBackupInfo();
    backupState.setBackupInfo(backupInfo);
    backupState.setProgress(1.0);
    backupState.setLoading(false);

    // Refresh settings so lastBackupTime/status propagate to the home
    // BackupHealthCard (Consumer<SettingsState>) immediately.
    await SettingsService.loadSettings(settingsState, settingsRepository);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncErrors.isEmpty
              ? 'Backup completed successfully'
              : 'Backup completed, but some files failed to sync'),
          backgroundColor: syncErrors.isEmpty
              ? Theme.of(context).colorScheme.primary
              : Colors.orange,
        ),
      );
    }
    return true;
  } on DriveAuthException catch (e) {
    // Drive needs an interactive re-consent — a plain retry can't fix it.
    // Record the typed error (so the home BackupHealthCard switches its button
    // to "Sign in & back up") and guide the user with a friendly message
    // instead of a scary "Backup failed". Never a sign-out / data loss.
    backupState.setLoading(false);
    try {
      await BackupTimeService.recordFailed(
        settingsRepository: settingsRepository,
        error: e.toString(),
      );
      await SettingsService.loadSettings(settingsState, settingsRepository);
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${e.message} Use "Sign in & back up".')),
      );
    }
    return false;
  } on EmptyBackupException {
    // The uploadBackup backstop fired (the pre-check above normally catches
    // this first). Not a failure — same gentle nudge, no error state.
    backupState.setLoading(false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nothing to back up yet — add a customer or order first. '
            'Your existing backup is safe.',
          ),
        ),
      );
    }
    return false;
  } catch (e) {
    backupState.setError('Backup failed: $e');
    try {
      await BackupTimeService.recordFailed(
        settingsRepository: settingsRepository,
        error: e.toString(),
      );
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
    return false;
  }
}
