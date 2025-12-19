import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import 'widgets/app_logo.dart';

class BackupRestoreCheckScreen extends StatefulWidget {
  const BackupRestoreCheckScreen({super.key});

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
    _checkForBackup();
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

      backupState.setProgress(0.4);
      backupState.setProgress(0.6);

      await BackupService.restoreBackup(backupJson);

      backupState.setProgress(0.9);

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
        Navigator.of(context).pushReplacementNamed(AppConstants.homeRoute);
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

  void _handleSkip() {
    Navigator.of(context).pushReplacementNamed(AppConstants.homeRoute);
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
                  return _buildRestoringView(backupState.progress);
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
        const SizedBox(height: AppConfig.spacing16),
        Text(
          'We found a backup for your account.\nWould you like to restore it?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConfig.spacing32),
        FilledButton(
          onPressed: _handleRestore,
          child: const Text('Restore Backup'),
        ),
        const SizedBox(height: AppConfig.spacing16),
        OutlinedButton(
          onPressed: _handleSkip,
          child: const Text('Start Fresh'),
        ),
      ],
    );
  }

  Widget _buildRestoringView(double progress) {
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
          '${(progress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

