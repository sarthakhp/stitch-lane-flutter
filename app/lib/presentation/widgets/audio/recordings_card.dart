import 'dart:io';

import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/services/sync/media_resolver.dart';
import 'audio_recording_player.dart';

/// A single titled card listing every recording for an entity, one compact
/// [AudioRecordingPlayer] per resolvable file. Used on measurement detail,
/// order detail, and the edit form so audio looks the same everywhere.
///
/// On the writer / a single device the stored paths exist on disk and the card
/// renders synchronously with no flicker. On a reader the paths are foreign, so
/// each is resolved by basename and lazy-downloaded from Drive on view via
/// [MediaResolver]. Files that can't be resolved (offline / not on Drive) are
/// skipped; when none remain, shows [emptyLabel] if given, else nothing.
class RecordingsCard extends StatefulWidget {
  final List<String> filePaths;
  final String? emptyLabel;

  const RecordingsCard({
    super.key,
    required this.filePaths,
    this.emptyLabel,
  });

  @override
  State<RecordingsCard> createState() => _RecordingsCardState();
}

class _RecordingsCardState extends State<RecordingsCard> {
  // Resolution future, used only when some paths aren't already on disk.
  Future<List<String>>? _resolved;

  @override
  void initState() {
    super.initState();
    if (!_allPresentLocally) _resolved = _resolveAll();
  }

  @override
  void didUpdateWidget(RecordingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameList(oldWidget.filePaths, widget.filePaths)) {
      _resolved = _allPresentLocally ? null : _resolveAll();
    }
  }

  bool get _allPresentLocally =>
      widget.filePaths.every((p) => File(p).existsSync());

  Future<List<String>> _resolveAll() async {
    final out = <String>[];
    for (final path in widget.filePaths) {
      final file = await MediaResolver.resolveAudio(path);
      if (file != null) out.add(file.path);
    }
    return out;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Fast path: everything is on disk (writer / single device / already
    // downloaded) — render exactly as before, no async, no flicker.
    if (_allPresentLocally) {
      return _card(
        context,
        widget.filePaths.where((p) => File(p).existsSync()).toList(),
      );
    }

    return FutureBuilder<List<String>>(
      future: _resolved,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _loadingCard(context);
        }
        return _card(context, snap.data ?? const []);
      },
    );
  }

  Widget _card(BuildContext context, List<String> paths) {
    final theme = Theme.of(context);

    if (paths.isEmpty) {
      if (widget.emptyLabel == null) return const SizedBox.shrink();
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              Icon(Icons.mic_off, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Text(
                  widget.emptyLabel!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final multiple = paths.length > 1;
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
                        ? 'Audio Recordings (${paths.length})'
                        : 'Audio Recording',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing8),
            for (var i = 0; i < paths.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppConfig.spacing8),
                child: AudioRecordingPlayer(
                  key: ValueKey(paths[i]),
                  filePath: paths[i],
                  label: multiple ? 'Recording ${i + 1}' : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _loadingCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppConfig.spacing16),
            Expanded(
              child: Text(
                'Loading recordings…',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
