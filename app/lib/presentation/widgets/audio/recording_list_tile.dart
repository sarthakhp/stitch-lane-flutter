import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/services/audio/audio_playback_coordinator.dart';

/// Compact, list-friendly audio row: a play/pause button, a title + subtitle,
/// and an optional tap-through affordance. Manages its own [AudioPlayer] and
/// loads the file lazily on first play, so a list of these stays cheap.
///
/// Once a recording is playing (or paused mid-track) a slim seek bar with
/// elapsed/total times appears under the title; it hides again when playback
/// completes, keeping the row compact at rest.
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
  Duration _position = Duration.zero;
  Duration? _duration;

  /// The seek bar is shown once playback has started and stays while paused
  /// mid-track; it disappears when the track completes (position reset to 0).
  bool get _showSeekBar => _isPlaying || _position > Duration.zero;

  @override
  void dispose() {
    AudioPlaybackCoordinator.instance.release(this);
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player ??= _createPlayer();
    if (_isPlaying) {
      await player.pause();
      AudioPlaybackCoordinator.instance.release(this);
      return;
    }
    // Claim playback before resuming so any other tile pauses first.
    AudioPlaybackCoordinator.instance.claim(this, () => player.pause());
    if (!_loaded) {
      await player.setSourceDeviceFile(widget.filePath);
      _loaded = true;
    }
    await player.resume();
  }

  Future<void> _seekTo(Duration position) async {
    await _player?.seek(position);
    if (mounted) setState(() => _position = position);
  }

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    player.onPlayerComplete.listen((_) {
      AudioPlaybackCoordinator.instance.release(this);
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
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
                  if (_showSeekBar) ...[
                    const SizedBox(height: AppConfig.spacing8),
                    _SeekBar(
                      position: _position,
                      duration: _duration,
                      onSeek: _seekTo,
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

/// Slim progress + scrub control with elapsed / total time labels. Disabled
/// (no drag) until the player reports a non-zero duration.
class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration? duration;
  final ValueChanged<Duration> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMs = duration?.inMilliseconds ?? 0;
    final hasDuration = totalMs > 0;
    final value =
        hasDuration ? position.inMilliseconds.clamp(0, totalMs).toDouble() : 0.0;
    final timeStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            max: hasDuration ? totalMs.toDouble() : 1.0,
            onChanged: hasDuration
                ? (ms) => onSeek(Duration(milliseconds: ms.round()))
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConfig.spacing8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position), style: timeStyle),
              if (hasDuration)
                Text(_formatDuration(duration!), style: timeStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// Formats a duration as `m:ss` (e.g. `0:07`, `3:42`).
String _formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
