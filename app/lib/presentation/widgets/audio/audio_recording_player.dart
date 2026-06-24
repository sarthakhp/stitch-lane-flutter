import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../utils/wav_duration.dart';

/// Compact, single-recording player: a circular play/pause button, a slim
/// seek bar, and elapsed / total time. One consistent control used wherever a
/// recording is played (measurement & order detail, the edit form), grouped
/// under [RecordingsCard].
class AudioRecordingPlayer extends StatefulWidget {
  final String filePath;

  /// Optional small label above the seek bar (e.g. "Recording 2") — shown when
  /// a measurement/order has more than one recording.
  final String? label;

  const AudioRecordingPlayer({
    super.key,
    required this.filePath,
    this.label,
  });

  @override
  State<AudioRecordingPlayer> createState() => _AudioRecordingPlayerState();
}

class _AudioRecordingPlayerState extends State<AudioRecordingPlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _loaded = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    // Show the total length up front from the file SIZE — no decoding/loading.
    // The player reports the authoritative duration once playback starts.
    final estimate = WavDuration.fromFile(File(widget.filePath));
    if (estimate != null) _duration = estimate;
  }

  /// Open the audio source the first time it's actually needed (play or seek),
  /// so a screen full of recordings doesn't load them all up front.
  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    await _player.setSourceDeviceFile(widget.filePath);
    _loaded = true;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    await _ensureLoaded();
    await _player.resume();
  }

  Future<void> _seek(double seconds) async {
    await _ensureLoaded();
    await _player.seek(Duration(seconds: seconds.round()));
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxSeconds =
        _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final value = _position.inSeconds.clamp(0, maxSeconds.toInt()).toDouble();

    return Row(
      children: [
        _PlayButton(isPlaying: _isPlaying, onTap: _toggle),
        const SizedBox(width: AppConfig.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.label != null)
                Text(
                  widget.label!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: value,
                  max: maxSeconds,
                  onChanged: (v) => _seek(v),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppConfig.spacing8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position), style: theme.textTheme.labelSmall),
                    Text(_fmt(_duration), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
