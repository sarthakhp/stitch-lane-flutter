import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';

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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

