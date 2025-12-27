import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../config/app_config.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _RecordingState _state = _RecordingState.loading;
  String? _errorMessage;
  late AnimationController _pulseController;
  Timer? _maxDurationTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  static const String _tempFileName = 'temp_order_transcription';
  static const int _maxRecordingSeconds = 180;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startRecording();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_state == _RecordingState.recording || _state == _RecordingState.paused) {
        _cancelRecording();
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
        _startTimers();
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

  void _startTimers() {
    _maxDurationTimer = Timer(const Duration(seconds: _maxRecordingSeconds), () {
      if (_state == _RecordingState.recording && mounted) {
        _completeRecording(triggeredByTimeout: true);
      }
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _state == _RecordingState.recording) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _cancelTimers() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  Future<void> _togglePauseResume() async {
    if (_state == _RecordingState.recording) {
      await AudioRecordingService.pauseRecording();
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _pulseController.stop();
      if (mounted) {
        setState(() {
          _state = _RecordingState.paused;
        });
      }
    } else if (_state == _RecordingState.paused) {
      await AudioRecordingService.resumeRecording();
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _state == _RecordingState.recording) {
          setState(() {
            _elapsedSeconds++;
          });
        }
      });
      _pulseController.repeat(reverse: true);
      if (mounted) {
        setState(() {
          _state = _RecordingState.recording;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _cancelTimers();
    try {
      await AudioRecordingService.stopRecording();
      await AudioRecordingService.deleteTemporaryAudio();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(null);
    }
  }

  Future<void> _completeRecording({bool triggeredByTimeout = false}) async {
    _cancelTimers();
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
      if (mounted) {
        Navigator.of(context).pop(null);
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _cancelRecording();
        }
      },
      child: AlertDialog(
        content: _buildContent(context),
        actions: _buildActions(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecordingOrPaused =
        _state == _RecordingState.recording || _state == _RecordingState.paused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_state == _RecordingState.loading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: AppConfig.spacing24),
          Text(
            'Starting microphone...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ] else if (_state == _RecordingState.error) ...[
          Icon(
            Icons.error_outline,
            size: 48,
            color: colorScheme.error,
          ),
          const SizedBox(height: AppConfig.spacing16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ] else if (isRecordingOrPaused) ...[
          _buildMicIcon(colorScheme),
          const SizedBox(height: AppConfig.spacing24),
          Text(
            _formatDuration(_elapsedSeconds),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
          ),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            _state == _RecordingState.paused ? 'Paused' : 'Recording...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppConfig.spacing24),
          _buildPauseResumeButton(colorScheme),
        ],
      ],
    );
  }

  Widget _buildMicIcon(ColorScheme colorScheme) {
    if (_state == _RecordingState.paused) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.mic_off,
          size: 40,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.errorContainer,
            boxShadow: [
              BoxShadow(
                color: colorScheme.error
                    .withValues(alpha: 0.3 + _pulseController.value * 0.2),
                blurRadius: 8 + _pulseController.value * 8,
                spreadRadius: _pulseController.value * 4,
              ),
            ],
          ),
          child: Icon(
            Icons.mic,
            size: 40,
            color: colorScheme.onErrorContainer,
          ),
        );
      },
    );
  }

  Widget _buildPauseResumeButton(ColorScheme colorScheme) {
    final isPaused = _state == _RecordingState.paused;

    if (isPaused) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: _togglePauseResume,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow),
              SizedBox(width: AppConfig.spacing8),
              Text('Resume'),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
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
      return [
        TextButton(
          onPressed: _cancelRecording,
          child: const Text('Cancel'),
        ),
      ];
    }

    if (_state == _RecordingState.error) {
      return [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('OK'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _cancelRecording,
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => _completeRecording(),
        child: const Text('Done'),
      ),
    ];
  }
}

