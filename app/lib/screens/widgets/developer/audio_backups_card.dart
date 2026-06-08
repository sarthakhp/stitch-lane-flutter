import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';

/// Developer-only control to immediately sweep orphaned audio-backup files
/// (those not linked to a measurement), bypassing the usual grace periods.
class AudioBackupsCard extends StatefulWidget {
  const AudioBackupsCard({super.key});

  @override
  State<AudioBackupsCard> createState() => _AudioBackupsCardState();
}

class _AudioBackupsCardState extends State<AudioBackupsCard> {
  bool _isRunning = false;
  CleanupResult? _lastResult;

  Future<void> _deleteNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete orphan audio now?'),
        content: const Text(
          'Removes every audio backup file not linked to a measurement, '
          'ignoring the usual 30-day / 7-day grace periods. Files modified '
          'in the last 24 hours are still skipped to avoid hitting an '
          'active recording.\n\n'
          'Files linked to a saved measurement are never touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRunning = true);
    final result = await AudioBackupCleanupService.runCleanup(
      orphanedWavGrace: Duration.zero,
      stalePcmGrace: Duration.zero,
    );
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _lastResult = result;
    });

    final freedMb = (result.bytesFreed / 1024 / 1024).toStringAsFixed(2);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.deleted == 0
              ? 'No orphans to delete (kept ${result.kept})'
              : 'Deleted ${result.deleted} files, freed ${freedMb}MB '
                  '(kept ${result.kept})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delete_sweep, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text('Audio Backups', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              'Voice recordings are kept on disk as a safety net. Files '
              'linked to a measurement stay forever; orphans are normally '
              'swept after 30 days. Use this to delete orphans immediately.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing12),
            FilledButton.tonalIcon(
              onPressed: _isRunning ? null : _deleteNow,
              icon: _isRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: Text(_isRunning ? 'Cleaning…' : 'Delete orphans now'),
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: AppConfig.spacing8),
              Text(
                'Last run: kept ${_lastResult!.kept}, '
                'deleted ${_lastResult!.deleted}, '
                'freed ${(_lastResult!.bytesFreed / 1024 / 1024).toStringAsFixed(2)}MB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
