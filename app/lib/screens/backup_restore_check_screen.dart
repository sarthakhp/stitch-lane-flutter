import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import 'widgets/app_logo.dart';
import '../presentation/widgets/confirmation_dialog.dart';

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
      if (!mounted) return;

      if (backupInfo == null) {
        // No backup to restore — there's nothing for the user to decide, so
        // skip this screen entirely and go straight into the app. We keep
        // _isChecking == true (don't flip to the "No backup found" view) so
        // the splash stays up with no flash until onComplete navigates away.
        if (widget.onComplete != null) {
          widget.onComplete!.call();
          return;
        }
        // Defensive fallback (callback not wired): show the manual view.
        setState(() {
          _hasBackup = false;
          _isChecking = false;
        });
        return;
      }

      setState(() {
        _hasBackup = true;
        _isChecking = false;
      });
    } catch (e) {
      // On error we do NOT auto-skip: we genuinely don't know whether a
      // backup exists, and "starting fresh" could orphan a real backup the
      // user just can't reach right now. Surface the error so they can retry.
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

    // ── SAFETY: confirm + snapshot before any restore ──
    //
    // We hit a real production data-loss event from this code path: the user
    // had ~24h of unbacked-up local data that got silently overwritten when
    // a sign-in flow ran this restore. So we now:
    //   1. Read the LIVE local counts and show them in the confirmation
    //   2. Warn prominently if the local DB has non-zero data
    //   3. Take a local snapshot (DbSnapshotService) before overwriting so
    //      the user can always roll back via the Developer screen
    int localCustomers = 0, localOrders = 0, localMeasurements = 0;
    try {
      localCustomers = (await customerRepository.getAllCustomers()).length;
      localOrders = (await orderRepository.getAllOrders()).length;
      localMeasurements = (await measurementRepository.getAllMeasurements()).length;
    } catch (e) {
      AppLogger.warning('BackupRestoreCheckScreen: failed to read local counts: $e');
    }
    if (!mounted) return;

    final hasLocalData =
        localCustomers + localOrders + localMeasurements > 0;
    // Nothing local to lose → restore straight away, no warning. Only prompt
    // when there's local data that could be overwritten.
    if (hasLocalData) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: const Text('Restore from Drive backup?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will replace your current local data with the Drive '
                  'backup. Anything in the local DB that is newer than the '
                  'backup will be overwritten.',
                ),
                const SizedBox(height: AppConfig.spacing12),
                Text(
                  'Current local data on this device:',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppConfig.spacing4),
                Text('  • Customers: $localCustomers'),
                Text('  • Orders: $localOrders'),
                Text('  • Measurements: $localMeasurements'),
                const SizedBox(height: AppConfig.spacing12),
                Container(
                  padding: const EdgeInsets.all(AppConfig.spacing8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: AppConfig.spacing8),
                      Expanded(
                        child: Text(
                          'You already have local data. If it is newer than '
                          'the backup, restoring will lose it.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppConfig.spacing12),
                Text(
                  'A local snapshot will be taken before restoring so you can '
                  'roll back from the Developer screen if needed.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                child: const Text('Overwrite & restore'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) return;
    }

    // Take the safety snapshot. Forced (ignores throttle) so it always runs
    // regardless of when the last automatic snapshot happened.
    final snapshot = await DbSnapshotService.snapshotNow();
    if (snapshot == null) {
      AppLogger.warning(
        'BackupRestoreCheckScreen: pre-restore snapshot failed — restore continues',
      );
    } else {
      AppLogger.info(
        'BackupRestoreCheckScreen: pre-restore snapshot saved at ${snapshot.dir.path}',
      );
    }
    if (!mounted) return;

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
        onImageProgress: (current, total, message) {
          backupState.setDetailedProgress(
            0.5 + (current / total) * 0.2,
            message,
          );
        },
        onAudioProgress: (current, total, message) {
          backupState.setDetailedProgress(
            0.7 + (current / total) * 0.2,
            message,
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
    // Starting fresh can permanently discard the existing backup, so confirm
    // twice to be sure it isn't an accidental tap.
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Start Fresh?',
      content:
          'Your previous backup data will not be restored and may be permanently lost if you continue.\n\nAre you sure you want to start fresh?',
      confirmText: 'Start Fresh',
      cancelText: 'Go Back',
    );
    if (!confirmed || !mounted) return;

    final confirmedAgain = await ConfirmationDialog.show(
      context: context,
      title: 'Are you absolutely sure?',
      content:
          'This is your last chance. Your previous backup will not be restored and may be lost forever.\n\nTap "Start Fresh" only if you are certain.',
      confirmText: 'Start Fresh',
      cancelText: 'Go Back',
    );
    if (!confirmedAgain || !mounted) return;

    widget.onComplete?.call();
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
          // No backup exists, so there's nothing to lose — go straight in
          // without the "Start Fresh?" data-loss confirmation (that warning
          // only makes sense when a backup is actually present).
          onPressed: () => widget.onComplete?.call(),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildBackupFoundView() {
    final auth = context.read<AuthController>();
    final displayName = auth.name;
    final email = auth.email;

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
    // Confirm twice — signing out clears local data.
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out? All local data will be cleared.',
      confirmText: 'Sign Out',
    );
    if (!confirmed || !mounted) return;

    final confirmedAgain = await ConfirmationDialog.show(
      context: context,
      title: 'Are you absolutely sure?',
      content:
          'This is your last chance. All local data on this device will be cleared. Make sure you have a backup before signing out.',
      confirmText: 'Sign Out',
    );
    if (!confirmedAgain || !mounted) return;

    // Gate-rendered screen: signing out flips status to unauthenticated and the
    // gate routes to LoginScreen — no manual navigation here.
    await context.read<AuthController>().signOut(
          customerRepository: context.read<CustomerRepository>(),
          orderRepository: context.read<OrderRepository>(),
          measurementRepository: context.read<MeasurementRepository>(),
          settingsRepository: context.read<SettingsRepository>(),
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

