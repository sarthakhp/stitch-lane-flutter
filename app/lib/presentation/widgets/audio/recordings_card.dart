import 'dart:io';

import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import 'audio_recording_player.dart';

/// A single titled card listing every recording for an entity, one compact
/// [AudioRecordingPlayer] per existing file. Used on measurement detail, order
/// detail, and the edit form so audio looks the same everywhere.
///
/// Files that no longer exist on disk are skipped. When none remain, shows
/// [emptyLabel] if given, otherwise renders nothing.
class RecordingsCard extends StatelessWidget {
  final List<String> filePaths;
  final String? emptyLabel;

  const RecordingsCard({
    super.key,
    required this.filePaths,
    this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing =
        filePaths.where((p) => File(p).existsSync()).toList(growable: false);

    if (existing.isEmpty) {
      if (emptyLabel == null) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              Icon(Icons.mic_off, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Text(
                  emptyLabel!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final multiple = existing.length > 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing12),
                Expanded(
                  child: Text(
                    multiple
                        ? 'Audio Recordings (${existing.length})'
                        : 'Audio Recording',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            for (var i = 0; i < existing.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
                child: AudioRecordingPlayer(
                  key: ValueKey(existing[i]),
                  filePath: existing[i],
                  label: multiple ? 'Recording ${i + 1}' : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
