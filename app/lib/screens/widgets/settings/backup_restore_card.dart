import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';
import '../confirmation_dialog.dart';

class BackupRestoreCard extends StatelessWidget {
  final VoidCallback? onRestoreComplete;

  const BackupRestoreCard({super.key, this.onRestoreComplete});

  @override
  Widget build(BuildContext context) {
    return Consumer<BackupState>(
      builder: (context, backupState, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup & Restore',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  'Backup your data to Google Drive',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppConfig.spacing16),
                if (backupState.backupInfo != null) ...[
                  ListTile(
                    leading: const Icon(Icons.cloud_done),
                    title: const Text('Last Backup'),
                    subtitle: Text(
                      '${_formatDate(backupState.backupInfo!.lastModified)} • ${backupState.backupInfo!.formattedSize}',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppConfig.spacing16),
                ],
                if (backupState.errorMessage != null) ...[
                  _buildErrorContainer(context, backupState.errorMessage!),
                  const SizedBox(height: AppConfig.spacing16),
                ],
                if (backupState.isLoading) ...[
                  LinearProgressIndicator(value: backupState.progress > 0 ? backupState.progress : null),
                  const SizedBox(height: AppConfig.spacing16),
                ],
                OutlinedButton.icon(
                  onPressed: backupState.isLoading ? null : () => _handleDriveSignIn(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in to Google Drive'),
                ),
                const SizedBox(height: AppConfig.spacing16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: backupState.isLoading ? null : () => _handleBackup(context),
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Backup Now'),
                      ),
                    ),
                    const SizedBox(width: AppConfig.spacing16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: backupState.isLoading ? null : () => _handleRestore(context),
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Restore'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorContainer(BuildContext context, String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y h:mm a').format(date);
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
      content: 'This will backup all your data (customers, orders, settings) to Google Drive. Any existing backup will be replaced.',
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

      final backupInfo = await DriveService.getBackupInfo();
      backupState.setBackupInfo(backupInfo);

      backupState.setProgress(1.0);
      backupState.setLoading(false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup completed successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
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
      final images = await DriveServiceImageOperations.listImagesInFolder(driveApi);
      final imageCount = images.length;

      if (!context.mounted) return;

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: 'Restore from Backup',
        content: 'This will replace all current data with the backup from ${_formatDate(DateTime.parse(metadata['timestamp']))}.\n\nBackup contains:\n• ${metadata['customerCount']} customers\n• ${metadata['orderCount']} orders\n• ${metadata['measurementCount']} measurements\n• $imageCount images\n\nThis action cannot be undone.',
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
      await MeasurementService.loadMeasurements(measurementState, measurementRepository);
      await SettingsService.loadSettings(settingsState, settingsRepository);

      backupState.setProgress(1.0);
      backupState.setLoading(false);

      onRestoreComplete?.call();

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
}

