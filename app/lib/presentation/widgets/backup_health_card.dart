import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../backend/backend.dart';
import '../../config/app_config.dart';
import '../../domain/domain.dart';

/// Always-visible "is my data safe in the cloud?" card. Replaces silent
/// backup failures with a banner that turns red the moment a backup is
/// missing or failing. Three states:
///
///   - green:  most recent backup succeeded within 24h
///   - yellow: backup is 24–72h old, OR last attempt was partial
///   - red:    backup is >72h old, last attempt failed, or never backed up
///
/// A "Back up now" button triggers [AutoBackupService.performBackup] inline.
/// After completion the SettingsState is reloaded from disk, so the card
/// auto-refreshes without a manual rebuild.
class BackupHealthCard extends StatefulWidget {
  const BackupHealthCard({super.key});

  @override
  State<BackupHealthCard> createState() => _BackupHealthCardState();
}

class _BackupHealthCardState extends State<BackupHealthCard> {
  bool _isBackingUp = false;

  Future<void> _backupNow() async {
    setState(() => _isBackingUp = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AutoBackupService.performBackup();
      // performBackup() writes status into the settings DB; reload SettingsState
      // so the card paints with the new timestamp / status immediately.
      if (!mounted) return;
      final state = context.read<SettingsState>();
      final repo = context.read<SettingsRepository>();
      await SettingsService.loadSettings(state, repo);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Backup complete')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsState>(
      builder: (context, state, _) {
        final last = state.lastBackupTime;
        final status = state.settings.lastBackupStatus;
        final error = state.settings.lastBackupError;

        final health = _computeHealth(last, status);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final (bg, fg, icon) = switch (health) {
          _Health.green => (
              scheme.primaryContainer,
              scheme.onPrimaryContainer,
              Icons.cloud_done_outlined,
            ),
          _Health.yellow => (
              Colors.amber.shade100,
              Colors.amber.shade900,
              Icons.cloud_outlined,
            ),
          _Health.red => (
              scheme.errorContainer,
              scheme.onErrorContainer,
              Icons.cloud_off_outlined,
            ),
        };

        return Card(
          color: bg,
          margin: EdgeInsets.zero,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(AppConfig.spacing12),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 28),
                const SizedBox(width: AppConfig.spacing12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title(health, last, status),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(health, last, error),
                        style: theme.textTheme.bodySmall?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConfig.spacing8),
                TextButton(
                  onPressed: _isBackingUp ? null : _backupNow,
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: _isBackingUp
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      : const Text('Back up now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static _Health _computeHealth(DateTime? last, String? status) {
    if (last == null) return _Health.red;
    if (status == 'failed') return _Health.red;
    final age = DateTime.now().difference(last);
    // Partial counts as yellow at minimum, red if it's also stale.
    if (status == 'partial') {
      return age.inHours >= 72 ? _Health.red : _Health.yellow;
    }
    if (age.inHours >= 72) return _Health.red;
    if (age.inHours >= 24) return _Health.yellow;
    return _Health.green;
  }

  static String _title(_Health h, DateTime? last, String? status) {
    if (last == null) return 'No backup yet';
    final age = _ago(DateTime.now().difference(last));
    if (status == 'failed') return 'Last backup failed';
    if (status == 'partial') return 'Last backup partial ($age)';
    return switch (h) {
      _Health.green => 'Backed up $age',
      _Health.yellow => 'Last backed up $age',
      _Health.red => 'Backup overdue ($age)',
    };
  }

  static String _subtitle(_Health h, DateTime? last, String? error) {
    if (last == null) {
      return 'Tap "Back up now" to save your data to Google Drive.';
    }
    final dateLine = DateFormat('MMM d, h:mm a').format(last);
    if (error != null && error.isNotEmpty) {
      // Keep one-line to avoid blowing up the card height.
      final flat = error.replaceAll('\n', ' ').trim();
      final clipped = flat.length > 90 ? '${flat.substring(0, 89)}…' : flat;
      return '$dateLine · $clipped';
    }
    return dateLine;
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

enum _Health { green, yellow, red }
