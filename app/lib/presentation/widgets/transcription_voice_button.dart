import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../config/app_config.dart';

class TranscriptionVoiceButton extends StatefulWidget {
  final Function(String? audioFilePath) onRecordingComplete;

  const TranscriptionVoiceButton({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<TranscriptionVoiceButton> createState() => _TranscriptionVoiceButtonState();
}

class _TranscriptionVoiceButtonState extends State<TranscriptionVoiceButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isRecording = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  Timer? _maxDurationTimer;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  static const String _tempFileName = 'temp_order_transcription';
  static const int _maxRecordingSeconds = 180; // 3 minutes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_isRecording) {
        _stopRecording(triggeredByLifecycle: true);
      }
    }
  }

  void _onTap() {
    if (_isLoading) return;

    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await AudioRecordingService.hasPermission();

      if (!hasPermission) {
        final granted = await AudioRecordingService.requestPermission();
        if (!granted) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission is required to record audio'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      final filePath = await AudioRecordingService.startRecording(_tempFileName);
      if (filePath != null && mounted) {
        setState(() {
          _isLoading = false;
          _isRecording = true;
          _elapsedSeconds = 0;
        });
        _startTimers();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start recording'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _startTimers() {
    _maxDurationTimer = Timer(const Duration(seconds: _maxRecordingSeconds), () {
      if (_isRecording && mounted) {
        _stopRecording(triggeredByTimeout: true);
      }
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording) {
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

  Future<void> _stopRecording({
    bool triggeredByTimeout = false,
    bool triggeredByLifecycle = false,
  }) async {
    _cancelTimers();

    try {
      final filePath = await AudioRecordingService.stopRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _elapsedSeconds = 0;
        });

        if (triggeredByTimeout) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording stopped: 3 minute limit reached'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        if (!triggeredByLifecycle) {
          widget.onRecordingComplete(filePath);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _elapsedSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
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
    if (_isRecording) {
      AudioRecordingService.stopRecording();
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final colorScheme = Theme.of(context).colorScheme;
          final Color containerColor;
          final Color borderColor;
          final Color contentColor;

          if (_isLoading) {
            containerColor = colorScheme.surfaceContainerHighest;
            borderColor = colorScheme.outline;
            contentColor = colorScheme.onSurface;
          } else if (_isRecording) {
            containerColor = colorScheme.errorContainer;
            borderColor = colorScheme.error;
            contentColor = colorScheme.onErrorContainer;
          } else {
            containerColor = colorScheme.primaryContainer;
            borderColor = colorScheme.primary;
            contentColor = colorScheme.onPrimaryContainer;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
                  border: Border.all(
                    color: borderColor,
                    width: 2,
                  ),
                ),
                child: _isLoading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: contentColor,
                          ),
                        ),
                      )
                    : Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 24 + (_isRecording ? _animationController.value * 4 : 0),
                        color: contentColor,
                      ),
              ),
              if (_isRecording)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDuration(_elapsedSeconds),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

