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
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isLoading = false;
  late AnimationController _animationController;

  static const String _tempFileName = 'temp_order_transcription';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
        });
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

  Future<void> _stopRecording() async {
    try {
      final filePath = await AudioRecordingService.stopRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        widget.onRecordingComplete(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
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

          return Container(
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
          );
        },
      ),
    );
  }
}

