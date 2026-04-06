import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import 'widgets/app_logo.dart';
import 'widgets/confirmation_dialog.dart';

class BackupRestoreCheckScreen extends StatefulWidget {
  final bool? hasBackup;
  final String? errorMessage;
  final bool alreadyChecked;
  final VoidCallback? onComplete;

  const BackupRestoreCheckScreen({
    super.key,
    this.hasBackup,
    this.errorMessage,
    this.alreadyChecked = false,
    this.onComplete,
  });

  @override
  State<BackupRestoreCheckScreen> createState() => _BackupRestoreCheckScreenState();
}

class _BackupRestoreCheckScreenState extends State<BackupRestoreCheckScreen> {
  bool _isChecking = true;
  bool _hasBackup = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.alreadyChecked) {
      _hasBackup = widget.hasBackup ?? false;
      _errorMessage = widget.errorMessage;
      _isChecking = false;
    } else {
      _checkForBackup();
    }
  }

  Future<void> _checkForBackup() async {
    try {
      final backupInfo = await DriveService.getBackupInfo();
      if (mounted) {
        setState(() {
          _hasBackup = backupInfo != null;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isChecking = false;
          _hasBackup = false;
        });
      }
    }
  }

  Future<void> _handleRestore() async {
    if (!mounted) return;

    final backupState = context.read<BackupState>();
    final customerState = context.read<CustomerState>();
    final orderState = context.read<OrderState>();
    final measurementState = context.read<MeasurementState>();
    final settingsState = context.read<SettingsState>();
    final customerRepository = context.read<CustomerRepository>();
    final orderRepository = context.read<OrderRepository>();
    final measurementRepository = context.read<MeasurementRepository>();
    final settingsRepository = context.read<SettingsRepository>();

    try {
      backupState.setLoading(true);
      backupState.setProgress(0.2);

      final backupJson = await DriveService.downloadBackup();

      if (backupJson == null) {
        backupState.setError('No backup found on Google Drive');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No backup found on Google Drive'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      backupState.setDetailedProgress(0.4, 'Restoring data...');

      await BackupService.restoreBackup(
        backupJson,
        customerRepository: customerRepository,
        orderRepository: orderRepository,
        measurementRepository: measurementRepository,
        settingsRepository: settingsRepository,
        onImageProgress: (current, total) {
          backupState.setDetailedProgress(
            0.5 + (current / total) * 0.2,
            'Restoring images $current / $total',
          );
        },
        onAudioProgress: (current, total) {
          backupState.setDetailedProgress(
            0.7 + (current / total) * 0.2,
            'Restoring audio $current / $total',
          );
        },
      );

      backupState.setDetailedProgress(0.95, 'Loading data...');

      await CustomerService.loadCustomers(customerState, customerRepository);
      await OrderService.loadOrders(orderState, orderRepository);
      await MeasurementService.loadMeasurements(measurementState, measurementRepository);
      await SettingsService.loadSettings(settingsState, settingsRepository);

      backupState.setProgress(1.0);
      backupState.setLoading(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Backup restored successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        widget.onComplete?.call();
      }
    } catch (e) {
      backupState.setError(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore backup: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSkip() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Start Fresh?',
      content:
          'Your previous backup data will not be restored and may be permanently lost if you continue.\n\nAre you sure you want to start fresh?',
      confirmText: 'Start Fresh',
      cancelText: 'Go Back',
    );

    if (confirmed && mounted) {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing32),
            child: Consumer<BackupState>(
              builder: (context, backupState, child) {
                if (_isChecking) {
                  return _buildCheckingView();
                }

                if (_errorMessage != null) {
                  return _buildErrorView();
                }

                if (!_hasBackup) {
                  return _buildNoBackupView();
                }

                if (backupState.isLoading) {
                  return _buildRestoringView(backupState);
                }

                return _buildBackupFoundView();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppLogo(),
        const SizedBox(height: AppConfig.spacing48),
        const CircularProgressIndicator(),
        const SizedBox(height: AppConfig.spacing24),
        Text(
          'Checking for backup...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppLogo(),
        const SizedBox(height: AppConfig.spacing48),
        Icon(
          Icons.error_outline,
          size: AppConfig.largeIconSize,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: AppConfig.spacing24),
        Text(
          'Unable to check for backup',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing16),
        Text(
          _errorMessage ?? 'An error occurred',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing32),
        FilledButton(
          onPressed: _handleSkip,
          child: const Text('Continue to App'),
        ),
      ],
    );
  }

  Widget _buildNoBackupView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppLogo(),
        const SizedBox(height: AppConfig.spacing48),
        Icon(
          Icons.cloud_off,
          size: AppConfig.largeIconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppConfig.spacing24),
        Text(
          'No backup found',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing16),
        Text(
          'Starting fresh with a new account',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing32),
        FilledButton(
          onPressed: _handleSkip,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildBackupFoundView() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName;
    final email = user?.email;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppLogo(),
        const SizedBox(height: AppConfig.spacing48),
        Icon(
          Icons.cloud_done,
          size: AppConfig.largeIconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppConfig.spacing24),
        Text(
          'Backup Found!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing8),
        if (displayName != null)
          Text(
            displayName,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        if (email != null)
          Text(
            email,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: AppConfig.spacing16),
        Text(
          'We found a backup for your account.\nWould you like to restore it?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing32),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _handleRestore,
            icon: const Icon(Icons.cloud_download),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppConfig.spacing8),
              child: Text(
                'Restore Backup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConfig.spacing24),
        TextButton(
          onPressed: _handleSkip,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: const Text('Skip and start fresh'),
        ),
        const SizedBox(height: AppConfig.spacing8),
        TextButton.icon(
          onPressed: _handleSignOut,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  Future<void> _handleSignOut() async {
    final customerRepository = context.read<CustomerRepository>();
    final orderRepository = context.read<OrderRepository>();
    final measurementRepository = context.read<MeasurementRepository>();
    final settingsRepository = context.read<SettingsRepository>();

    await AuthService.signOut(
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      measurementRepository: measurementRepository,
      settingsRepository: settingsRepository,
    );
  }

  Widget _buildRestoringView(BackupState backupState) {
    final progress = backupState.progress;
    final message = backupState.progressMessage;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppLogo(),
        const SizedBox(height: AppConfig.spacing48),
        CircularProgressIndicator(value: progress),
        const SizedBox(height: AppConfig.spacing24),
        Text(
          'Restoring backup...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppConfig.spacing16),
        Text(
          message ?? '${(progress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

