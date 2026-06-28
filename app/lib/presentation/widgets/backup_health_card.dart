import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../domain/domain.dart';
import '../../domain/state/sync_state.dart';
import '../backup_flow.dart';

/// "Is my data safe in the cloud?" banner, shown on the home screen only when
/// backup needs attention. It surfaces silent backup problems instead of
/// letting them go unnoticed:
///
///   - green:  succeeded within 24h  -> card is HIDDEN (nothing to act on)
///   - yellow: backup is 24–72h old, OR last attempt was partial
///   - red:    backup is >72h old, last attempt failed, or never backed up
///
/// The "Back up now" button runs the shared [runManualBackup] flow (same as
/// the Settings backup button). It reloads SettingsState on completion, so the
/// Consumer below repaints — and the card hides itself once backup goes green.
class BackupHealthCard extends StatefulWidget {
  const BackupHealthCard({super.key});

  @override
  State<BackupHealthCard> createState() => _BackupHealthCardState();
}

class _BackupHealthCardState extends State<BackupHealthCard> {
  bool _isBackingUp = false;

  Future<void> _backupNow() async {
    setState(() => _isBackingUp = true);
    try {
      // Use the shared foreground backup flow (same one the Settings backup
      // button uses): confirmation dialog -> backup -> Drive upload -> sync ->
      // reload settings -> snackbar. It reloads SettingsState itself, so the
      // Consumer<SettingsState> wrapping this card repaints with the fresh
      // timestamp/status automatically.
      await runManualBackup(context);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  /// Recovery for a Drive RE-AUTH failure: a plain "Back up now" would just hit
  /// the same dead token. Reconnect Google Drive first (interactive sign-in
  /// that touches ONLY the Drive grant — never the app session or local data),
  /// then run the normal backup. If the user cancels the Google prompt, nothing
  /// changes.
  Future<void> _reauthAndBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final reconnected = await DriveAuthService.reconnect();
      if (!reconnected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Google Drive sign-in cancelled. Your data and app sign-in '
                'are untouched.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await runManualBackup(context);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A reader device doesn't own the cloud backup — the primary device does.
    // Hide the nudge entirely so we never prompt a reader to back up.
    final canWrite = context.select<SyncState, bool>((s) => s.canWrite);
    if (!canWrite) return const SizedBox.shrink();

    // Nothing to lose, nothing to warn about. A brand-new account (no
    // customers, no orders) shouldn't be nagged to back up empty data — the
    // nudge appears the moment real data exists.
    final hasData = context.watch<OrderState>().orders.isNotEmpty ||
        context.watch<CustomerState>().customers.isNotEmpty;
    if (!hasData) return const SizedBox.shrink();

    return Consumer<SettingsState>(
      builder: (context, state, _) {
        final last = state.lastBackupTime;
        final status = state.settings.lastBackupStatus;
        final error = state.settings.lastBackupError;

        final health = _computeHealth(last, status);

        // A failed backup caused specifically by Drive needing re-authentication
        // can't be fixed by retrying the same flow — offer to reconnect Drive
        // first. (Drive grant only; the app session is never touched.)
        final needsReauth =
            health == _Health.red && DriveAuthException.matches(error);

        // When the last backup succeeded and is recent (green), hide the card
        // entirely — there's nothing to act on, so it shouldn't take up home
        // screen space. It reappears only when attention is warranted:
        // yellow (24-72h old / partial) or red (>72h / failed / never).
        if (health == _Health.green) {
          return const SizedBox.shrink();
        }

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
          // Own the trailing gap so home doesn't reserve space when this card
          // is hidden (new account / healthy backup → SizedBox.shrink above).
          margin: const EdgeInsets.only(bottom: AppConfig.spacing16),
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
                        needsReauth
                            ? 'Sign in to keep backups safe'
                            : _title(health, last, status),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        needsReauth
                            ? _reauthSubtitle(last)
                            : _subtitle(health, last, error),
                        style: theme.textTheme.bodySmall?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConfig.spacing8),
                TextButton(
                  onPressed: _isBackingUp
                      ? null
                      : (needsReauth ? _reauthAndBackup : _backupNow),
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
                      : Text(needsReauth ? 'Sign in & back up' : 'Back up now'),
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

  static String _reauthSubtitle(DateTime? last) {
    if (last == null) {
      return 'Sign in to Google Drive to start backing up.';
    }
    final dateLine = DateFormat('MMM d, h:mm a').format(last);
    return '$dateLine · Reconnect Google Drive to resume backups.';
  }

  static String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

enum _Health { green, yellow, red }
