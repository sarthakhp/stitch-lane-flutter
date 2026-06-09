import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../domain/services/recordings/recording_metadata.dart';
import '../domain/services/recordings/recording_store.dart';
import '../presentation/presentation.dart';
import 'widgets/recordings/recording_tile.dart';

/// Developer tool: browse every voice recording by date, play it back, and see
/// the transcript + what the AI did. The single place to debug "she said it
/// didn't work" — find the recording, hear what was said, see what happened.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  late Future<List<RecordingEntry>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    // Block body (not `=>`): an arrow closure would *return* the assigned
    // Future, and setState rejects a callback that returns a Future.
    setState(() {
      _future = RecordingStore.listAll();
    });
  }

  Future<void> _deleteOld() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete old recordings?'),
        content: const Text(
          'Permanently removes every recording older than 30 days (audio + '
          'transcript/AI details). Recent ones are kept.',
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
    if (confirmed != true) return;
    final removed =
        await RecordingStore.deleteOlderThan(const Duration(days: 30));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(removed == 0
            ? 'Nothing older than 30 days'
            : 'Deleted $removed old recording${removed == 1 ? '' : 's'}'),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Recordings'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'refresh') _refresh();
              if (v == 'delete_old') _deleteOld();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh')),
              PopupMenuItem(
                value: 'delete_old',
                child: Text('Delete older than 30 days'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<RecordingEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? const <RecordingEntry>[];
          if (entries.isEmpty) return _buildEmpty(context);
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppConfig.spacing16),
              children: _buildItems(context, entries),
            ),
          );
        },
      ),
    );
  }

  /// Flattens entries into date headers + tiles. Entries arrive newest-first.
  List<Widget> _buildItems(BuildContext context, List<RecordingEntry> entries) {
    final theme = Theme.of(context);
    final items = <Widget>[];
    String? currentDay;
    for (final entry in entries) {
      final day = _dayLabel(entry.createdAt);
      if (day != currentDay) {
        currentDay = day;
        items.add(Padding(
          padding: EdgeInsets.only(
            top: items.isEmpty ? 0 : AppConfig.spacing16,
            bottom: AppConfig.spacing8,
          ),
          child: Text(
            day,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
      }
      items.add(RecordingTile(entry: entry, onChanged: _refresh));
    }
    return items;
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppConfig.spacing12),
            Text(
              'No recordings yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              'Voice dictations (Create Order, measurements, the AI assistant) '
              'show up here with their transcript and what the AI did.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM y').format(d);
  }
}
