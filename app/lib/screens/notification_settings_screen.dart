import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/domain.dart';
import '../backend/backend.dart';
import '../config/app_config.dart';
import '../presentation/presentation.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.loadSettings(settingsState, settingsRepository);
  }

  Future<void> _saveSettings(AppSettings newSettings) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();

    await SettingsService.updateSettings(
      settingsState,
      settingsRepository,
      newSettings,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (settingsState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settingsState.error!),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _onReminderToggled(bool enabled) async {
    final settingsState = context.read<SettingsState>();
    final newSettings = settingsState.settings.copyWith(
      pendingOrdersReminderEnabled: enabled,
    );
    await _saveSettings(newSettings);
  }

  Future<void> _onTimeSelected() async {
    final settingsState = context.read<SettingsState>();
    final currentTime = _parseTimeOfDay(settingsState.pendingOrdersReminderTime);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (selectedTime != null && mounted) {
      final timeString = _formatTimeOfDay(selectedTime);
      final newSettings = settingsState.settings.copyWith(
        pendingOrdersReminderTime: timeString,
      );
      await _saveSettings(newSettings);
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 30;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 8, minute: 30);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeForDisplay(String timeString) {
    final time = _parseTimeOfDay(timeString);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('Notification Settings'),
      ),
      body: Consumer<SettingsState>(
        builder: (context, settingsState, child) {
          if (settingsState.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppConfig.spacing16),
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
                          'Pending Orders Reminder',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppConfig.spacing8),
                        Text(
                          'Get a daily reminder about pending orders',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: AppConfig.spacing16),
                        SwitchListTile(
                          title: const Text('Enable Reminder'),
                          subtitle: const Text('Receive daily notifications'),
                          value: settingsState.pendingOrdersReminderEnabled,
                          onChanged: _isSaving ? null : _onReminderToggled,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (settingsState.pendingOrdersReminderEnabled) ...[
                          const Divider(),
                          const SizedBox(height: AppConfig.spacing8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Reminder Time',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _isSaving ? null : _onTimeSelected,
                                icon: const Icon(Icons.access_time, size: 18),
                                label: Text(
                                  _formatTimeForDisplay(settingsState.pendingOrdersReminderTime),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

