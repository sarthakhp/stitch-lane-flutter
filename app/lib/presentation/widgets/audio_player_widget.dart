import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../config/app_config.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioFilePath;

  const AudioPlayerWidget({
    super.key,
    required this.audioFilePath,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      }
    });

    await _loadAudioFile();
  }

  Future<void> _loadAudioFile() async {
    final file = File(widget.audioFilePath);
    if (await file.exists()) {
      await _audioPlayer.stop();
      await _audioPlayer.release();
      setState(() {
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
      });
      await _audioPlayer.setSourceDeviceFile(widget.audioFilePath);
    }
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioFilePath != widget.audioFilePath) {
      _loadAudioFile();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.release();
      await _audioPlayer.setSourceDeviceFile(widget.audioFilePath);
      await _audioPlayer.resume();
    }
  }

  Future<void> _seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppConfig.spacing8),
                Text(
                  'Audio Recording',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing16),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayPause,
                  iconSize: 32,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0,
                        onChanged: (value) {
                          _seekTo(Duration(seconds: value.toInt()));
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConfig.spacing8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

