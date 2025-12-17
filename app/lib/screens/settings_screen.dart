import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sign Out',
      content: 'Are you sure you want to sign out?',
      confirmText: 'Sign Out',
    );

    if (confirmed && context.mounted) {
      final authState = context.read<AuthState>();
      await AuthService.signOut(authState);

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.loginRoute,
          (route) => false,
        );
      }
    }
  }
}

