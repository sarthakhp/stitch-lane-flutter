import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../config/app_config.dart';

/// Compact, list-friendly audio row: a play/pause button, a title + subtitle,
/// and an optional tap-through affordance. Manages its own [AudioPlayer] and
/// loads the file lazily on first play, so a list of these stays cheap.
///
/// For a single, prominent recording on a detail screen use the larger
/// `AudioPlayerWidget` (with a scrubber); this tile is for timelines/lists.
class RecordingListTile extends StatefulWidget {
  final String filePath;
  final String title;
  final String? subtitle;

  /// Optional leading chip text (e.g. "Order" / "Measurement").
  final String? badge;

  /// Tapping the row (not the play button) calls this — e.g. open the source.
  final VoidCallback? onOpen;

  const RecordingListTile({
    super.key,
    required this.filePath,
    required this.title,
    this.subtitle,
    this.badge,
    this.onOpen,
  });

  @override
  State<RecordingListTile> createState() => _RecordingListTileState();
}

class _RecordingListTileState extends State<RecordingListTile> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _loaded = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player ??= _createPlayer();
    if (_isPlaying) {
      await player.pause();
      return;
    }
    if (!_loaded) {
      await player.setSourceDeviceFile(widget.filePath);
      _loaded = true;
    }
    await player.resume();
  }

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
    return player;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: widget.onOpen,
      borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing12,
          vertical: AppConfig.spacing8,
        ),
        child: Row(
          children: [
            _PlayButton(isPlaying: _isPlaying, onTap: _toggle),
            const SizedBox(width: AppConfig.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.badge != null) ...[
                        _Badge(text: widget.badge!),
                        const SizedBox(width: AppConfig.spacing8),
                      ],
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onOpen != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
