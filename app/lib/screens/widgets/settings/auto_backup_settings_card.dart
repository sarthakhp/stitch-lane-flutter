import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';

class AutoBackupSettingsCard extends StatefulWidget {
  const AutoBackupSettingsCard({super.key});

  @override
  State<AutoBackupSettingsCard> createState() => _AutoBackupSettingsCardState();
}

class _AutoBackupSettingsCardState extends State<AutoBackupSettingsCard> {
  bool _isSaving = false;

  Future<void> _saveSettings(AppSettings newSettings, {bool scheduleChanged = false}) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();

    await SettingsService.updateSettings(settingsState, settingsRepository, newSettings);

    if (scheduleChanged && mounted) {
      await _updateBackupSchedule(newSettings);
    }

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

  Future<void> _updateBackupSchedule(AppSettings settings) async {
    if (settings.autoBackupEnabled) {
      await AutoBackupService.scheduleAutoBackup(settings.autoBackupTime);
    } else {
      await AutoBackupService.cancelAutoBackup();
    }
  }

  Future<void> _onAutoBackupToggled(bool enabled) async {
    final settingsState = context.read<SettingsState>();
    final newSettings = settingsState.settings.copyWith(autoBackupEnabled: enabled);
    await _saveSettings(newSettings, scheduleChanged: true);
  }

  Future<void> _onTimeSelected() async {
    final settingsState = context.read<SettingsState>();
    final currentTime = _parseTimeOfDay(settingsState.autoBackupTime);

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
      final newSettings = settingsState.settings.copyWith(autoBackupTime: timeString);
      await _saveSettings(newSettings, scheduleChanged: true);
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 3;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 3, minute: 0);
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

  String _formatLastBackupTime(DateTime? lastBackup) {
    if (lastBackup == null) return 'Never';
    return DateFormat('MMM d, y h:mm a').format(lastBackup);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsState>(
      builder: (context, settingsState, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Automatic Backup', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  'Automatically backup your data to Google Drive',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppConfig.spacing16),
                SwitchListTile(
                  title: const Text('Enable Auto-Backup'),
                  subtitle: const Text('Backup daily at scheduled time'),
                  value: settingsState.autoBackupEnabled,
                  onChanged: _isSaving ? null : _onAutoBackupToggled,
                  contentPadding: EdgeInsets.zero,
                ),
                if (settingsState.autoBackupEnabled) ...[
                  const Divider(),
                  const SizedBox(height: AppConfig.spacing8),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Backup Time', style: Theme.of(context).textTheme.bodyLarge),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSaving ? null : _onTimeSelected,
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(_formatTimeForDisplay(settingsState.autoBackupTime)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppConfig.spacing16),
                _buildLastBackupInfo(context, settingsState.lastBackupTime),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLastBackupInfo(BuildContext context, DateTime? lastBackup) {
    return Row(
      children: [
        Icon(
          lastBackup != null ? Icons.check_circle_outline : Icons.info_outline,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppConfig.spacing8),
        Flexible(
          child: Text(
            'Last backup: ${_formatLastBackupTime(lastBackup)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

