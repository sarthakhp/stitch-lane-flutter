import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';
import '../../../presentation/widgets/confirmation_dialog.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
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
                if (authState.email != null) ...[
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(authState.email!),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppConfig.spacing8),
                ],
                if (authState.name != null) ...[
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Name'),
                    subtitle: Text(authState.name!),
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
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    // Signing out clears all local data, so confirm twice to be sure it isn't
    // an accidental tap.
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out? All local data will be cleared.',
      confirmText: 'Sign Out',
    );
    if (!confirmed || !context.mounted) return;

    final confirmedAgain = await ConfirmationDialog.show(
      context: context,
      title: 'Are you absolutely sure?',
      content:
          'This is your last chance. All local data on this device will be cleared. Make sure you have a backup before signing out.',
      confirmText: 'Sign Out',
    );

    if (confirmedAgain && context.mounted) {
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

      final authController = context.read<AuthController>();
      final customerState = context.read<CustomerState>();
      final orderState = context.read<OrderState>();
      final settingsState = context.read<SettingsState>();
      final backupState = context.read<BackupState>();
      final customerRepository = context.read<CustomerRepository>();
      final orderRepository = context.read<OrderRepository>();
      final measurementRepository = context.read<MeasurementRepository>();
      final settingsRepository = context.read<SettingsRepository>();

      try {
        await authController.signOut(
          customerRepository: customerRepository,
          orderRepository: orderRepository,
          measurementRepository: measurementRepository,
          settingsRepository: settingsRepository,
        );
      } catch (_) {
        // Auth already signed out; local cleanup failed but the auth gate will
        // still route to login once the status flips.
      }

      customerState.clearCustomers();
      orderState.clearOrders();
      settingsState.reset();
      backupState.reset();

      // Pop the loading dialog + this pushed Profile/Settings route back to the
      // gate (root), which now shows LoginScreen because status flipped to
      // unauthenticated. No manual navigation to login — single source.
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

