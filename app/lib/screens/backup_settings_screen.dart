import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';
import 'widgets/confirmation_dialog.dart';

enum _ExportSource { local, drive }

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBackupInfo());
  }

  Future<void> _loadBackupInfo() async {
    final backupState = context.read<BackupState>();
    backupState.setCheckingBackup(true);
    try {
      final backupInfo = await DriveService.getBackupInfo();
      backupState.setBackupInfo(backupInfo);
    } catch (e) {
      backupState.setBackupInfo(null);
    } finally {
      backupState.setCheckingBackup(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: Text('Backup & Restore')),
      body: Consumer2<BackupState, SettingsState>(
        builder: (context, backupState, settingsState, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BackupStatusSection(
                      backupState: backupState,
                      settingsState: settingsState,
                    ),
                    const SizedBox(height: AppConfig.spacing24),
                    _BackupActionsSection(
                      backupState: backupState,
                      onSignIn: () => _handleDriveSignIn(context),
                      onBackup: () => _handleBackup(context),
                      onRestore: () => _handleRestore(context),
                      onExport: () => _handleExport(context),
                      onImport: () => _handleImport(context),
                    ),
                    const SizedBox(height: AppConfig.spacing24),
                    _AutoBackupSection(
                      settingsState: settingsState,
                      isSaving: _isSaving,
                      onToggle: _onAutoBackupToggled,
                      onTimeSelected: _onTimeSelected,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDriveSignIn(BuildContext context) async {
    final backupState = context.read<BackupState>();
    try {
      backupState.setLoading(true);
      backupState.clearError();
      final googleSignIn = AuthService.googleSignIn;
      await googleSignIn.signIn();
      final backupInfo = await DriveService.getBackupInfo();
      backupState.setBackupInfo(backupInfo);
      backupState.setLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully signed in to Google Drive'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      backupState.setError('Drive sign-in failed: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drive sign-in failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleBackup(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Backup to Google Drive',
      content:
          'This will backup all your data (customers, orders, settings) to Google Drive. Any existing backup will be replaced.',
      confirmText: 'Backup',
    );
    if (!confirmed || !context.mounted) return;

    final backupState = context.read<BackupState>();
    try {
      final customerRepository = context.read<CustomerRepository>();
      final orderRepository = context.read<OrderRepository>();
      final measurementRepository = context.read<MeasurementRepository>();
      final settingsRepository = context.read<SettingsRepository>();

      backupState.setLoading(true);
      backupState.setProgress(0.2);
      final backupJson = await BackupService.createBackup(
        customerRepository: customerRepository,
        orderRepository: orderRepository,
        measurementRepository: measurementRepository,
        settingsRepository: settingsRepository,
      );
      backupState.setProgress(0.4);
      await DriveService.uploadBackup(backupJson);

      // File sync — track errors separately for partial status
      final syncErrors = <String>[];
      backupState.setDetailedProgress(0.5, 'Syncing images...');
      try {
        await ImageSyncService.syncImagesToDrive(
          orderRepository: orderRepository,
          onProgress: (current, total, message) {
            if (context.mounted) {
              final fraction = 0.5 + (current / total) * 0.2;
              backupState.setDetailedProgress(fraction, message);
            }
          },
        );
      } catch (e) {
        syncErrors.add('Images: $e');
      }
      backupState.setDetailedProgress(0.7, 'Syncing audio...');
      try {
        await AudioSyncService.syncAudiosToDrive(
          onProgress: (current, total, message) {
            if (context.mounted) {
              final fraction = 0.7 + (current / total) * 0.2;
              backupState.setDetailedProgress(fraction, message);
            }
          },
        );
      } catch (e) {
        syncErrors.add('Audio: $e');
      }

      backupState.setProgress(0.9);
      if (syncErrors.isEmpty) {
        await BackupTimeService.recordSuccess(settingsRepository: settingsRepository);
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
      if (context.mounted) {
        final settingsState = context.read<SettingsState>();
        final settingsRepository = context.read<SettingsRepository>();
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
      }
    } catch (e) {
      backupState.setError('Backup failed: ${e.toString()}');
      try {
        // ignore: use_build_context_synchronously
        final repo = context.read<SettingsRepository>();
        await BackupTimeService.recordFailed(
          settingsRepository: repo,
          error: e.toString(),
        );
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final backupState = context.read<BackupState>();
    try {
      backupState.setLoading(true);
      backupState.setProgress(0.2);
      final backupJson = await DriveService.downloadBackup();
      if (backupJson == null) {
        backupState.setError('No backup found on Google Drive');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No backup found on Google Drive'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      backupState.setProgress(0.4);
      final metadata = BackupService.getBackupMetadata(backupJson);
      final driveApi = await DriveService.getDriveApi();
      final images =
          await DriveServiceImageOperations.listImagesInFolder(driveApi);
      final imageCount = images.length;
      if (!context.mounted) return;

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Restore from Backup',
        content:
            'This will replace all current data with the backup from ${_formatDate(DateTime.parse(metadata['timestamp']))}.\n\nBackup contains:\n• ${metadata['customerCount']} customers\n• ${metadata['orderCount']} orders\n• ${metadata['measurementCount']} measurements\n• $imageCount images\n\nThis action cannot be undone.',
        confirmText: 'Restore',
        cancelText: 'Cancel',
      );
      if (!confirmed || !context.mounted) {
        backupState.reset();
        return;
      }

      final customerState = context.read<CustomerState>();
      final orderState = context.read<OrderState>();
      final measurementState = context.read<MeasurementState>();
      final settingsState = context.read<SettingsState>();
      final customerRepository = context.read<CustomerRepository>();
      final orderRepository = context.read<OrderRepository>();
      final measurementRepository = context.read<MeasurementRepository>();
      final settingsRepository = context.read<SettingsRepository>();

      backupState.setDetailedProgress(0.6, 'Restoring data...');
      await BackupService.restoreBackup(
        backupJson,
        customerRepository: customerRepository,
        orderRepository: orderRepository,
        measurementRepository: measurementRepository,
        settingsRepository: settingsRepository,
        onImageProgress: (current, total, message) {
          if (context.mounted) {
            backupState.setDetailedProgress(
              0.6 + (current / total) * 0.2,
              message,
            );
          }
        },
        onAudioProgress: (current, total, message) {
          if (context.mounted) {
            backupState.setDetailedProgress(
              0.8 + (current / total) * 0.1,
              message,
            );
          }
        },
      );
      backupState.setProgress(0.9);
      await CustomerService.loadCustomers(customerState, customerRepository);
      await OrderService.loadOrders(orderState, orderRepository);
      await MeasurementService.loadMeasurements(
          measurementState, measurementRepository);
      await SettingsService.loadSettings(settingsState, settingsRepository);
      backupState.setProgress(1.0);
      backupState.setLoading(false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data restored successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      backupState.setError('Restore failed: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    final source = await showDialog<_ExportSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Zip'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _ExportSource.local),
            child: const ListTile(
              leading: Icon(Icons.phone_android),
              title: Text('Export Local Data'),
              subtitle: Text('Current data on this device'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _ExportSource.drive),
            child: const ListTile(
              leading: Icon(Icons.cloud),
              title: Text('Export Drive Data'),
              subtitle: Text('Data stored on Google Drive'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
    if (source == null || !context.mounted) return;

    final backupState = context.read<BackupState>();
    try {
      backupState.setLoading(true);
      if (source == _ExportSource.local) {
        final customerRepository = context.read<CustomerRepository>();
        final orderRepository = context.read<OrderRepository>();
        final measurementRepository = context.read<MeasurementRepository>();
        final settingsRepository = context.read<SettingsRepository>();
        await BackupExportService.exportLocalBackupAsZip(
          customerRepository: customerRepository,
          orderRepository: orderRepository,
          measurementRepository: measurementRepository,
          settingsRepository: settingsRepository,
          onProgress: (status) {
            if (context.mounted) {
              backupState.setDetailedProgress(0.5, status);
            }
          },
        );
      } else {
        await BackupExportService.exportDriveBackupAsZip(
          onProgress: (status) {
            if (context.mounted) {
              backupState.setDetailedProgress(0.5, status);
            }
          },
        );
      }
      backupState.setLoading(false);
    } catch (e) {
      backupState.setError('Export failed: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }


  Future<void> _handleImport(BuildContext context) async {
    final backupState = context.read<BackupState>();

    try {
      // 1. Pick a zip file
      final zipPath = await BackupImportService.pickZipFile();
      if (zipPath == null || !context.mounted) return; // user cancelled

      // 2. Validate the zip (no data touched yet)
      backupState.setLoading(true);
      backupState.setDetailedProgress(0.1, 'Validating backup file...');

      final validation = await BackupImportService.validateZip(zipPath);
      if (!validation.success) {
        backupState.setError('Invalid backup: ${validation.error}');
        return;
      }

      backupState.setLoading(false);
      if (!context.mounted) return;

      // 3. Show confirmation dialog
      final metadata = validation.metadata!;
      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Import from Zip',
        content: 'This will replace all current data.\n\n'
            'Backup contains:\n'
            '• ${metadata['customerCount']} customers\n'
            '• ${metadata['orderCount']} orders\n'
            '• ${metadata['measurementCount']} measurements\n'
            '• ${metadata['imageCount']} images\n'
            '• ${metadata['audioCount']} audio files\n\n'
            'Your current data will be backed up in memory. If the import fails, it will be restored automatically.',
        confirmText: 'Import',
        cancelText: 'Cancel',
      );

      if (!confirmed || !context.mounted) {
        backupState.reset();
        return;
      }

      // 4. Perform the import
      backupState.setLoading(true);

      final customerRepository = context.read<CustomerRepository>();
      final orderRepository = context.read<OrderRepository>();
      final measurementRepository = context.read<MeasurementRepository>();
      final settingsRepository = context.read<SettingsRepository>();

      final result = await BackupImportService.importFromZip(
        zipPath,
        customerRepository: customerRepository,
        orderRepository: orderRepository,
        measurementRepository: measurementRepository,
        settingsRepository: settingsRepository,
        onProgress: (status) {
          if (context.mounted) {
            backupState.setDetailedProgress(0.5, status);
          }
        },
      );

      if (!result.success) {
        backupState.setError(result.error ?? 'Import failed');
        if (context.mounted) {
          // Reload states since rollback happened
          await _reloadAllStates(context);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Import failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // 5. Reload all states
      if (context.mounted) {
        await _reloadAllStates(context);
      }

      backupState.setProgress(1.0);
      backupState.setLoading(false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup imported successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      backupState.setError('Import failed: ${e.toString()}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _reloadAllStates(BuildContext context) async {
    final customerState = context.read<CustomerState>();
    final orderState = context.read<OrderState>();
    final measurementState = context.read<MeasurementState>();
    final settingsState = context.read<SettingsState>();
    final customerRepository = context.read<CustomerRepository>();
    final orderRepository = context.read<OrderRepository>();
    final measurementRepository = context.read<MeasurementRepository>();
    final settingsRepository = context.read<SettingsRepository>();

    await CustomerService.loadCustomers(customerState, customerRepository);
    await OrderService.loadOrders(orderState, orderRepository);
    await MeasurementService.loadMeasurements(measurementState, measurementRepository);
    await SettingsService.loadSettings(settingsState, settingsRepository);
  }

  String _formatDate(DateTime date) =>
      DateFormat('MMM d, y h:mm a').format(date);



  Future<void> _onAutoBackupToggled(bool enabled) async {
    final settingsState = context.read<SettingsState>();
    final newSettings =
        settingsState.settings.copyWith(autoBackupEnabled: enabled);
    await _saveSettings(newSettings, scheduleChanged: true);
  }

  Future<void> _onTimeSelected() async {
    final settingsState = context.read<SettingsState>();
    final currentTime = _parseTimeOfDay(settingsState.autoBackupTime);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (selectedTime != null && mounted) {
      final timeString = _formatTimeOfDay(selectedTime);
      final newSettings =
          settingsState.settings.copyWith(autoBackupTime: timeString);
      await _saveSettings(newSettings, scheduleChanged: true);
    }
  }

  Future<void> _saveSettings(AppSettings newSettings,
      {bool scheduleChanged = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.updateSettings(
        settingsState, settingsRepository, newSettings);
    if (scheduleChanged && mounted) {
      await _updateBackupSchedule(newSettings);
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<void> _updateBackupSchedule(AppSettings settings) async {
    if (settings.autoBackupEnabled) {
      await AutoBackupService.scheduleAutoBackup(settings.autoBackupTime);
    } else {
      await AutoBackupService.cancelAutoBackup();
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 3;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 3, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _BackupStatusSection extends StatelessWidget {
  final BackupState backupState;
  final SettingsState settingsState;

  const _BackupStatusSection({
    required this.backupState,
    required this.settingsState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text('Google Drive Backup', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConfig.spacing16),
            if (backupState.isCheckingBackup)
              _buildCheckingRow(context)
            else if (backupState.backupInfo != null) ...[
              _buildBackupStatusRow(context, settingsState),
              const SizedBox(height: AppConfig.spacing8),
              _buildInfoRow(
                context,
                Icons.account_circle,
                'Account',
                FirebaseAuth.instance.currentUser?.email ?? '—',
              ),
              const SizedBox(height: AppConfig.spacing8),
              _buildInfoRow(
                context,
                Icons.storage,
                'Backup Size',
                backupState.backupInfo!.formattedSize,
              ),
            ] else
              _buildInfoRow(context, Icons.cloud_off, 'Status',
                  'No backup found or not signed in'),
            if (backupState.errorMessage != null) ...[
              const SizedBox(height: AppConfig.spacing16),
              _buildErrorContainer(context, backupState.errorMessage!),
            ],
            if (backupState.isLoading) ...[
              const SizedBox(height: AppConfig.spacing16),
              if (backupState.progressMessage != null) ...[
                Text(
                  backupState.progressMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppConfig.spacing8),
              ],
              LinearProgressIndicator(
                  value:
                      backupState.progress > 0 ? backupState.progress : null),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckingRow(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppConfig.spacing8),
        Text(
          'Checking for backup...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBackupStatusRow(BuildContext context, SettingsState settingsState) {
    final status = settingsState.settings.lastBackupStatus;
    final error = settingsState.settings.lastBackupError;
    final lastTime = settingsState.lastBackupTime;

    final timeStr = lastTime != null
        ? DateFormat('MMM d, y h:mm a').format(lastTime)
        : 'Never';

    if (status == 'failed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(context, Icons.error_outline, 'Last Backup', 'Failed'),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: AppConfig.spacing4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (lastTime != null) ...[
            const SizedBox(height: AppConfig.spacing4),
            _buildInfoRow(context, Icons.cloud_done, 'Last Successful', timeStr),
          ],
        ],
      );
    }

    if (status == 'partial') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(context, Icons.warning_amber, 'Last Backup', 'Partial — $timeStr'),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: AppConfig.spacing4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (lastTime != null) ...[
            const SizedBox(height: AppConfig.spacing4),
            _buildInfoRow(context, Icons.cloud_done, 'Last Successful', timeStr),
          ],
        ],
      );
    }

    return _buildInfoRow(context, Icons.cloud_done, 'Last Backup', timeStr);
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppConfig.spacing8),
        Text('$label: ', style: theme.textTheme.bodyMedium),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContainer(BuildContext context, String errorMessage) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                  color: theme.colorScheme.onErrorContainer, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}



class _BackupActionsSection extends StatelessWidget {
  final BackupState backupState;
  final VoidCallback onSignIn;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const _BackupActionsSection({
    required this.backupState,
    required this.onSignIn,
    required this.onBackup,
    required this.onRestore,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppConfig.spacing16),
            OutlinedButton.icon(
              onPressed: backupState.isLoading ? null : onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign in to Google Drive'),
            ),
            const SizedBox(height: AppConfig.spacing12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: backupState.isLoading ? null : onBackup,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Backup Now'),
                      ),
                      const SizedBox(height: AppConfig.spacing12),
                      OutlinedButton.icon(
                        onPressed: backupState.isLoading ? null : onRestore,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Restore'),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: backupState.isLoading ? null : onBackup,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Backup Now'),
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacing16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: backupState.isLoading ? null : onRestore,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Restore'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppConfig.spacing12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: backupState.isLoading ? null : onExport,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Zip'),
                  ),
                ),
                const SizedBox(width: AppConfig.spacing16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: backupState.isLoading ? null : onImport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Zip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoBackupSection extends StatelessWidget {
  final SettingsState settingsState;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTimeSelected;

  const _AutoBackupSection({
    required this.settingsState,
    required this.isSaving,
    required this.onToggle,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text('Automatic Backup', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              'Automatically backup your data to Google Drive daily',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            SwitchListTile(
              title: const Text('Enable Auto-Backup'),
              subtitle: const Text('Backup daily at scheduled time'),
              value: settingsState.autoBackupEnabled,
              onChanged: isSaving ? null : onToggle,
              contentPadding: EdgeInsets.zero,
            ),
            if (settingsState.autoBackupEnabled) ...[
              const Divider(),
              const SizedBox(height: AppConfig.spacing8),
              Row(
                children: [
                  Expanded(
                    child: Text('Backup Time', style: theme.textTheme.bodyLarge),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: isSaving ? null : onTimeSelected,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                        _formatTimeForDisplay(settingsState.autoBackupTime)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimeForDisplay(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 3;
      final minute = int.tryParse(parts[1]) ?? 0;
      final time = TimeOfDay(hour: hour, minute: minute);
      final displayHour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final displayMinute = time.minute.toString().padLeft(2, '0');
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$displayHour:$displayMinute $period';
    }
    return '3:00 AM';
  }
}


