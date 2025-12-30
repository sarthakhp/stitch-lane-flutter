import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../domain/domain.dart';
import '../presentation/presentation.dart';
import 'widgets/confirmation_dialog.dart';

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
      backupState.setLoading(true);
      backupState.setProgress(0.2);
      final backupJson = await BackupService.createBackup();
      backupState.setProgress(0.4);
      await DriveService.uploadBackup(backupJson);
      backupState.setProgress(0.5);
      await ImageSyncService.syncImagesToDrive();
      backupState.setProgress(0.7);
      await AudioSyncService.syncAudiosToDrive();
      backupState.setProgress(0.9);
      await BackupTimeService.updateLastBackupTime();
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
              content: const Text('Backup completed successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      backupState.setError('Backup failed: ${e.toString()}');
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

      backupState.setProgress(0.6);
      await BackupService.restoreBackup(backupJson);
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
              _buildInfoRow(
                context,
                Icons.cloud_done,
                'Last Backup',
                settingsState.lastBackupTime != null
                    ? DateFormat('MMM d, y h:mm a')
                        .format(settingsState.lastBackupTime!)
                    : 'Never',
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

  const _BackupActionsSection({
    required this.backupState,
    required this.onSignIn,
    required this.onBackup,
    required this.onRestore,
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

