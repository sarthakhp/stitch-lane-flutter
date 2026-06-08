import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:intl/intl.dart';
import '../../../backend/backend.dart';
import '../../../config/app_config.dart';

/// Lists rotating local DB snapshots and lets you restore from one. This is
/// the data-loss safety net — surfaced first on the Developer screen.
///
/// Restore flow:
///   1. User taps Restore → confirmation dialog
///   2. App closes the live DB handle
///   3. Files from the snapshot are copied over the live DB position
///   4. App shows a "Reopen app" prompt and exits
///   5. On next launch the new files become the live DB (and a snapshot of
///      THIS state gets taken automatically before any further migration)
class LocalSnapshotsCard extends StatefulWidget {
  const LocalSnapshotsCard({super.key});

  @override
  State<LocalSnapshotsCard> createState() => _LocalSnapshotsCardState();
}

class _LocalSnapshotsCardState extends State<LocalSnapshotsCard> {
  Future<List<DbSnapshot>>? _future;
  bool _isWorking = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = DbSnapshotService.listSnapshots();
    });
  }

  Future<void> _snapshotNow() async {
    setState(() => _isWorking = true);
    final s = await DbSnapshotService.snapshotNow();
    if (!mounted) return;
    setState(() => _isWorking = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(s == null
          ? 'Snapshot failed — see logs'
          : 'Snapshot taken'),
    ));
    _refresh();
  }

  Future<void> _restore(DbSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from snapshot?'),
        content: Text(
          'This will REPLACE the current data with the snapshot from\n\n'
          '${DateFormat('MMM d, yyyy · h:mm a').format(snapshot.takenAt)}\n\n'
          'The app will close. Reopen it to load the restored data.\n\n'
          'A fresh snapshot of the current state will be taken automatically '
          'on next launch — this restore is reversible if you act quickly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isWorking = true);

    // Close the open DB handle so the file copy doesn't fight a lock.
    await SqliteDatabase.close();
    final ok = await DbSnapshotService.restoreFromSnapshot(snapshot);

    if (!mounted) return;
    setState(() => _isWorking = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore failed — see logs')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restored'),
        content: const Text(
          'Files restored successfully.\n\n'
          'Tap "Close app" and reopen to see the restored data.',
        ),
        actions: [
          FilledButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Close app'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(DbSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this snapshot?'),
        content: Text(
          'The snapshot from '
          '${DateFormat('MMM d, h:mm a').format(snapshot.takenAt)} will be '
          'permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await DbSnapshotService.deleteSnapshot(snapshot);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed — see logs')),
      );
    }
    _refresh();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
                Icon(Icons.shield_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(
                  child: Text('Local DB snapshots',
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: _isWorking ? null : _refresh,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing4),
            Text(
              'Automatic snapshots of stitch_genie.db taken at app launch '
              '(throttled to one per ${DbSnapshotService.minInterval.inMinutes} min). '
              'Restore here if anything ever overwrites the live data.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Snapshot now'),
              onPressed: _isWorking ? null : _snapshotNow,
            ),
            const SizedBox(height: AppConfig.spacing12),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppConfig.spacing8),
                    Text(
                      _expanded ? 'Hide snapshots' : 'Show snapshots',
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              FutureBuilder<List<DbSnapshot>>(
                future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppConfig.spacing16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snap.data ?? const <DbSnapshot>[];
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppConfig.spacing16),
                    child: Text(
                      'No snapshots yet — one will be taken next launch.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppConfig.spacing8),
                      child: Text(
                        '${list.length} of ${DbSnapshotService.maxSnapshots} · '
                        'oldest: ${DateFormat('MMM d').format(list.last.takenAt)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final s in list)
                      _SnapshotRow(
                        snapshot: s,
                        isWorking: _isWorking,
                        sizeLabel: _formatSize(s.sizeBytes),
                        onRestore: () => _restore(s),
                        onDelete: () => _delete(s),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final DbSnapshot snapshot;
  final bool isWorking;
  final String sizeLabel;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _SnapshotRow({
    required this.snapshot,
    required this.isWorking,
    required this.sizeLabel,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing4),
      child: Row(
        children: [
          Icon(Icons.history,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppConfig.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d, h:mm a').format(snapshot.takenAt),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  sizeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete snapshot',
            onPressed: isWorking ? null : onDelete,
          ),
          TextButton(
            onPressed: isWorking ? null : onRestore,
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
