import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_config.dart';
import '../../../domain/services/recordings/recording_metadata.dart';
import '../../../domain/services/recordings/recording_store.dart';
import '../../../presentation/widgets/audio_player_widget.dart';

/// One row in the Recordings debugger. Collapsed it shows time + source +
/// duration/size; expanded it plays the audio and shows the transcript and
/// "what the AI did", plus share/delete.
class RecordingTile extends StatelessWidget {
  final RecordingEntry entry;
  final VoidCallback onChanged;

  const RecordingTile({
    super.key,
    required this.entry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = entry.meta;
    final subtitle =
        '${DateFormat('h:mm a').format(entry.createdAt)} · '
        '${_fmtDuration(entry.duration)} · ${_fmtSize(entry.sizeBytes)}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppConfig.spacing8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppConfig.spacing16,
          0,
          AppConfig.spacing16,
          AppConfig.spacing12,
        ),
        title: Row(
          children: [
            _SourceChip(source: entry.source),
            const SizedBox(width: AppConfig.spacing8),
            Expanded(
              child: Text(
                meta?.title?.trim().isNotEmpty == true
                    ? meta!.title!
                    : entry.source.label,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        children: [
          AudioPlayerWidget(audioFilePath: entry.wav.path),
          const SizedBox(height: AppConfig.spacing12),
          if (meta?.transcript?.trim().isNotEmpty == true)
            _Section(
              label: 'Transcript',
              child: SelectableText(
                meta!.transcript!.trim(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (meta != null && meta.actions.isNotEmpty)
            _Section(
              label: 'What the AI did',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in meta.actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $line', style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          if (meta == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
              child: Text(
                'No transcript / action details were saved for this recording.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppConfig.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
              ),
              const SizedBox(width: AppConfig.spacing8),
              TextButton.icon(
                onPressed: () => _confirmDelete(context),
                icon: Icon(Icons.delete_outline,
                    size: 18, color: theme.colorScheme.error),
                label: Text('Delete',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(entry.wav.path)]),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text(
          'This permanently removes the audio and its transcript/AI details '
          'from this device.',
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
    await RecordingStore.delete(entry);
    messenger.showSnackBar(const SnackBar(content: Text('Recording deleted')));
    onChanged();
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Colored chip naming the voice flow that produced the recording.
class _SourceChip extends StatelessWidget {
  final RecordingSource source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (source) {
      RecordingSource.orderCreator => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          Icons.add_shopping_cart,
        ),
      RecordingSource.measurement => (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          Icons.straighten,
        ),
      RecordingSource.assistant => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          Icons.auto_awesome,
        ),
      RecordingSource.unknown => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          Icons.mic,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            source.label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConfig.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppConfig.spacing4),
          child,
        ],
      ),
    );
  }
}
