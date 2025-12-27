import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';

class DueDateWarningCard extends StatefulWidget {
  const DueDateWarningCard({super.key});

  @override
  State<DueDateWarningCard> createState() => _DueDateWarningCardState();
}

class _DueDateWarningCardState extends State<DueDateWarningCard> {
  late TextEditingController _thresholdController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController();
    _thresholdController.addListener(_onThresholdChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _thresholdController.removeListener(_onThresholdChanged);
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.loadSettings(settingsState, settingsRepository);
    if (mounted) {
      _thresholdController.removeListener(_onThresholdChanged);
      _thresholdController.text = settingsState.dueDateWarningThreshold.toString();
      _thresholdController.addListener(_onThresholdChanged);
    }
  }

  Future<void> _onThresholdChanged() async {
    final text = _thresholdController.text;
    if (text.isEmpty) return;

    final threshold = int.tryParse(text);
    if (threshold == null || threshold < 1) return;

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    final newSettings = settingsState.settings.copyWith(
      dueDateWarningThreshold: threshold,
    );

    await SettingsService.updateSettings(
      settingsState,
      settingsRepository,
      newSettings,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (settingsState.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settingsState.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
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
            TextField(
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
              enabled: !_isSaving,
            ),
          ],
        ),
      ),
    );
  }
}

