import 'package:flutter/material.dart';
import '../../domain/services/audio_recording_service.dart';
import '../../config/app_config.dart';

class VoiceRecorderButton extends StatefulWidget {
  final String? measurementId;
  final Function(String? audioFilePath) onRecordingComplete;
  final bool hasExistingRecording;

  const VoiceRecorderButton({
    super.key,
    this.measurementId,
    required this.onRecordingComplete,
    this.hasExistingRecording = false,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isLoading = false;
  late AnimationController _animationController;

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

      final filePath = widget.measurementId != null
          ? await AudioRecordingService.startRecording(widget.measurementId!)
          : await AudioRecordingService.startRecording('new_measurement_audio');
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppConfig.spacing8),
                Text(
                  widget.hasExistingRecording
                      ? 'Re-record Audio (Hold to Record)'
                      : 'Record Audio (Hold to Record)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing16),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final colorScheme = Theme.of(context).colorScheme;
                  final Color containerColor;
                  final Color borderColor;
                  final Color contentColor;

                  if (_isRecording) {
                    containerColor = colorScheme.errorContainer;
                    borderColor = colorScheme.error;
                    contentColor = colorScheme.error;
                  } else if (_isLoading) {
                    containerColor = colorScheme.secondaryContainer;
                    borderColor = colorScheme.secondary;
                    contentColor = colorScheme.secondary;
                  } else {
                    containerColor = colorScheme.primaryContainer;
                    borderColor = colorScheme.primary;
                    contentColor = colorScheme.primary;
                  }

                  return Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
                      border: Border.all(
                        color: borderColor,
                        width: _isRecording ? 2 + (_animationController.value * 2) : 2,
                      ),
                    ),
                    child: Center(
                      child: _isLoading
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: contentColor,
                                  ),
                                ),
                                const SizedBox(height: AppConfig.spacing8),
                                Text(
                                  'Starting...',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: contentColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  size: 32 + (_isRecording ? _animationController.value * 8 : 0),
                                  color: contentColor,
                                ),
                                const SizedBox(height: AppConfig.spacing8),
                                Text(
                                  _isRecording ? 'Recording...' : 'Hold to Record',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: contentColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

