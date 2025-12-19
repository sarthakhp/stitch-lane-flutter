import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'widgets/confirmation_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _thresholdController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadBackupInfo();
    });
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.loadSettings(settingsState, settingsRepository);
    _thresholdController.text = settingsState.dueDateWarningThreshold.toString();
  }

  Future<void> _loadBackupInfo() async {
    final backupState = context.read<BackupState>();
    try {
      final backupInfo = await DriveService.getBackupInfo();
      backupState.setBackupInfo(backupInfo);
    } catch (e) {
      backupState.setBackupInfo(null);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    final threshold = int.parse(_thresholdController.text);
    final newSettings = settingsState.settings.copyWith(
      dueDateWarningThreshold: threshold,
    );

    await SettingsService.updateSettings(
      settingsState,
      settingsRepository,
      newSettings,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (settingsState.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settingsState.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsState>(
        builder: (context, settingsState, child) {
          if (settingsState.isLoading && _thresholdController.text.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConfig.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Due Date Warning',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppConfig.spacing8),
                          Text(
                            'Configure when to show warning borders on orders',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: AppConfig.spacing24),
                          TextFormField(
                            controller: _thresholdController,
                            decoration: const InputDecoration(
                              labelText: 'Warning Threshold (days)',
                              helperText: 'Show warning when due date is within this many days',
                              border: OutlineInputBorder(),
                              suffixText: 'days',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: SettingsValidators.validateDueDateWarningThreshold,
                            enabled: !_isSaving,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacing24),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save Settings'),
                  ),
                  const SizedBox(height: AppConfig.spacing48),
                  Consumer<BackupState>(
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
                                Container(
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
                                          backupState.errorMessage!,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onErrorContainer,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                  ),
                  const SizedBox(height: AppConfig.spacing24),
                  Consumer<AuthState>(
                    builder: (context, authState, child) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppConfig.spacing16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: AppConfig.spacing16),
                              if (authState.userEmail != null) ...[
                                ListTile(
                                  leading: const Icon(Icons.email),
                                  title: const Text('Email'),
                                  subtitle: Text(authState.userEmail!),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                const SizedBox(height: AppConfig.spacing8),
                              ],
                              if (authState.userName != null) ...[
                                ListTile(
                                  leading: const Icon(Icons.person),
                                  title: const Text('Name'),
                                  subtitle: Text(authState.userName!),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                const SizedBox(height: AppConfig.spacing16),
                              ],
                              const Divider(),
                              const SizedBox(height: AppConfig.spacing16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: authState.isLoading ? null : () => _handleSignOut(context),
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign Out'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

      _thresholdController.text = settingsState.dueDateWarningThreshold.toString();

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

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out? All local data will be cleared.',
      confirmText: 'Sign Out',
    );

    if (confirmed && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(AppConfig.spacing24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: AppConfig.spacing16),
                    Text('Signing out...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final authState = context.read<AuthState>();
      final customerState = context.read<CustomerState>();
      final orderState = context.read<OrderState>();
      final settingsState = context.read<SettingsState>();
      final backupState = context.read<BackupState>();

      await AuthService.signOut(authState);

      customerState.clearCustomers();
      orderState.clearOrders();
      settingsState.reset();
      backupState.reset();

      if (context.mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.loginRoute,
          (route) => false,
        );
      }
    }
  }
}

