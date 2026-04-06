import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'audio_player_widget.dart';

enum TranscriptionErrorAction {
  retry,
  discard,
}

class TranscriptionErrorDialog extends StatelessWidget {
  final String errorMessage;
  final String audioFilePath;

  const TranscriptionErrorDialog({
    super.key,
    required this.errorMessage,
    required this.audioFilePath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: AppConfig.spacing8),
          const Text('Transcription Failed'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            Text(
              'Your recording is saved. You can play it back or retry.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppConfig.spacing16),
            AudioPlayerWidget(audioFilePath: audioFilePath),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(TranscriptionErrorAction.discard),
          child: const Text('Discard'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(TranscriptionErrorAction.retry),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  static Future<TranscriptionErrorAction?> show(
    BuildContext context, {
    required String errorMessage,
    required String audioFilePath,
  }) {
    return showDialog<TranscriptionErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TranscriptionErrorDialog(
        errorMessage: errorMessage,
        audioFilePath: audioFilePath,
      ),
    );
  }
}
