import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../backend/repositories/settings_repository.dart';
import '../../../config/app_config.dart';
import '../../../domain/services/log_manager_service.dart';
import '../../../domain/services/settings_service.dart';
import '../../../domain/state/settings_state.dart';
import '../../../utils/app_logger.dart';

class DebugLogsCard extends StatefulWidget {
  const DebugLogsCard({super.key});

  @override
  State<DebugLogsCard> createState() => _DebugLogsCardState();
}

class _DebugLogsCardState extends State<DebugLogsCard> {
  bool _isSaving = false;
  bool _isSharing = false;
  int _logFileSize = 0;

  @override
  void initState() {
    super.initState();
    _loadLogFileSize();
  }

  Future<void> _loadLogFileSize() async {
    try {
      final size = await LogManagerService.getLogFileSize();
      if (mounted) {
        setState(() {
          _logFileSize = size;
        });
      }
    } catch (e) {
      // Silently fail - don't show errors for background operations
      if (mounted) {
        setState(() {
          _logFileSize = 0;
        });
      }
    }
  }

  Future<void> _onDebugLogsToggled(bool value) async {
    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
      });

      final settingsState = context.read<SettingsState>();
      final settingsRepository = context.read<SettingsRepository>();
      final newSettings = settingsState.settings.copyWith(
        debugLogsEnabled: value,
      );

      await SettingsService.updateSettings(
        settingsState,
        settingsRepository,
        newSettings,
      );

      if (value) {
        await AppLogger.enableFileLogging();
      } else {
        AppLogger.disableFileLogging();
      }

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle debug logs: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _onShareLogs() async {
    if (_isSharing) return;

    try {
      setState(() {
        _isSharing = true;
      });

      try {
        final success = await LogManagerService.shareLogsAsFile(minutes: 30);

        if (!mounted) return;

        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No logs found from the last 30 minutes'),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share logs: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // Catch any setState errors
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An error occurred: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } catch (_) {
          // Silently fail if even showing the error fails
        }
      }
    } finally {
      if (mounted) {
        try {
          setState(() {
            _isSharing = false;
          });
        } catch (_) {
          // Silently fail if setState fails
        }
      }
    }
  }

  Future<void> _onClearLogs() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Logs'),
          content: const Text('Are you sure you want to clear all logs?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        await AppLogger.clearLogs();
        await _loadLogFileSize();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared successfully')),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear logs: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      // Catch any dialog or other errors
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An error occurred: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } catch (_) {
          // Silently fail if even showing the error fails
        }
      }
    }
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
                Text(
                  'Debug Logs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppConfig.spacing8),
                Text(
                  'Enable logging to file for debugging purposes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppConfig.spacing16),
                SwitchListTile(
                  title: const Text('Enable Debug Logs'),
                  subtitle: const Text('Save logs to file'),
                  value: settingsState.debugLogsEnabled,
                  onChanged: _isSaving ? null : _onDebugLogsToggled,
                  contentPadding: EdgeInsets.zero,
                ),
                if (settingsState.debugLogsEnabled) ...[
                  const Divider(),
                  const SizedBox(height: AppConfig.spacing8),
                  if (_logFileSize > 0) ...[
                    Text(
                      'Log file size: ${LogManagerService.formatFileSize(_logFileSize)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: AppConfig.spacing16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSharing ? null : _onShareLogs,
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.share),
                          label: const Text('Share Last 30 Min'),
                        ),
                      ),
                      const SizedBox(width: AppConfig.spacing8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _logFileSize > 0 ? _onClearLogs : null,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear Logs'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

