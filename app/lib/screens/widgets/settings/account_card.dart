import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../confirmation_dialog.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
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
    );
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

