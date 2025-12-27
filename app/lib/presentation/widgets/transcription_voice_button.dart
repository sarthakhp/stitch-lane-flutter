import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'recording_dialog.dart';

class TranscriptionVoiceButton extends StatelessWidget {
  final Function(String? audioFilePath) onRecordingComplete;
  final bool expandWidth;

  const TranscriptionVoiceButton({
    super.key,
    required this.onRecordingComplete,
    this.expandWidth = false,
  });

  Future<void> _onTap(BuildContext context) async {
    final audioFilePath = await RecordingDialog.show(context);
    onRecordingComplete(audioFilePath);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: expandWidth ? double.infinity : 48,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          border: Border.all(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.mic,
          size: 24,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

