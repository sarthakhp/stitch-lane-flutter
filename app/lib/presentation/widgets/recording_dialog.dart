import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../domain/services/amplitude_tracker.dart';
import '../../config/app_config.dart';
import 'audio_waveform.dart';

enum _RecordingState { loading, recording, paused, error }

class RecordingDialog extends StatefulWidget {
  const RecordingDialog({super.key});

  @override
  State<RecordingDialog> createState() => _RecordingDialogState();

  static Future<String?> show(BuildContext context) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const RecordingDialog(),
    );
  }
}

class _RecordingDialogState extends State<RecordingDialog>
    with WidgetsBindingObserver {
  _RecordingState _state = _RecordingState.loading;
  String? _errorMessage;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  late final AmplitudeTracker _amplitudeTracker;

  static const String _tempFileName = 'temp_order_transcription';
  static const int _maxRecordingSeconds = 180;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _amplitudeTracker = AmplitudeTracker(
      onUpdate: () { if (mounted) setState(() {}); },
    );
    _startRecording();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_state == _RecordingState.recording) {
        _togglePauseResume();
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await AudioRecordingService.hasPermission();
      if (!hasPermission) {
        final granted = await AudioRecordingService.requestPermission();
        if (!granted) {
          if (mounted) {
            setState(() {
              _state = _RecordingState.error;
              _errorMessage = 'Microphone permission is required';
            });
          }
          return;
        }
      }

      final filePath = await AudioRecordingService.startRecording(_tempFileName);
      if (filePath != null && mounted) {
        setState(() {
          _state = _RecordingState.recording;
          _elapsedSeconds = 0;
        });
        _startElapsedTimer();
        _amplitudeTracker.start();
      } else if (mounted) {
        setState(() {
          _state = _RecordingState.error;
          _errorMessage = 'Failed to start recording';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _RecordingState.error;
          _errorMessage = 'Failed to start recording: $e';
        });
      }
    }
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _state == _RecordingState.recording) {
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= _maxRecordingSeconds) {
          _completeRecording(triggeredByTimeout: true);
        }
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  Future<void> _togglePauseResume() async {
    if (_state == _RecordingState.recording) {
      await AudioRecordingService.pauseRecording();
      _stopElapsedTimer();
      _amplitudeTracker.stop();
      if (mounted) setState(() => _state = _RecordingState.paused);
    } else if (_state == _RecordingState.paused) {
      await AudioRecordingService.resumeRecording();
      _startElapsedTimer();
      _amplitudeTracker.start();
      if (mounted) setState(() => _state = _RecordingState.recording);
    }
  }

  Future<void> _cancelRecording() async {
    _stopElapsedTimer();
    _amplitudeTracker.stop();
    try {
      await AudioRecordingService.stopRecording();
      await AudioRecordingService.deleteTemporaryAudio();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(null);
  }

  Future<void> _completeRecording({bool triggeredByTimeout = false}) async {
    _stopElapsedTimer();
    _amplitudeTracker.stop();
    try {
      final filePath = await AudioRecordingService.stopRecording();
      if (mounted) {
        if (triggeredByTimeout) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording stopped: 3 minute limit reached'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        Navigator.of(context).pop(filePath);
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(null);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopElapsedTimer();
    _amplitudeTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancelRecording();
      },
      child: AlertDialog(
        content: _buildContent(context),
        actions: _buildActions(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isRecordingOrPaused =
        _state == _RecordingState.recording || _state == _RecordingState.paused;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_state == _RecordingState.loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: AppConfig.spacing24),
            Text('Starting microphone...', style: theme.textTheme.titleMedium),
          ] else if (_state == _RecordingState.error) ...[
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: AppConfig.spacing16),
            Text(
              _errorMessage ?? 'An error occurred',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ] else if (isRecordingOrPaused) ...[
            AudioWaveform(
              levels: _amplitudeTracker.levels,
              isPaused: _state == _RecordingState.paused,
            ),
            const SizedBox(height: AppConfig.spacing12),
            Text(
              _formatDuration(_elapsedSeconds),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: [const FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppConfig.spacing4),
            Text(
              _state == _RecordingState.paused ? 'Paused' : 'Recording...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            _buildPauseResumeButton(colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildPauseResumeButton(ColorScheme colorScheme) {
    final isPaused = _state == _RecordingState.paused;
    return SizedBox(
      width: double.infinity,
      child: isPaused
          ? FilledButton.tonal(
              onPressed: _togglePauseResume,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: AppConfig.spacing8),
                  Text('Resume'),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: _togglePauseResume,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause),
                  SizedBox(width: AppConfig.spacing8),
                  Text('Pause'),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    if (_state == _RecordingState.loading) {
      return [TextButton(onPressed: _cancelRecording, child: const Text('Cancel'))];
    }
    if (_state == _RecordingState.error) {
      return [FilledButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('OK'))];
    }
    return [
      TextButton(onPressed: _cancelRecording, child: const Text('Cancel')),
      FilledButton(onPressed: () => _completeRecording(), child: const Text('Done')),
    ];
  }
}
