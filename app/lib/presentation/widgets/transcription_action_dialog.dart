import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'markdown_description_text.dart';

enum TranscriptionAction {
  append,
  cancel,
}

class TranscriptionActionDialog extends StatelessWidget {
  final String transcribedText;
  final bool hasExistingDescription;

  const TranscriptionActionDialog({
    super.key,
    required this.transcribedText,
    required this.hasExistingDescription,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transcription Complete'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Transcribed text:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppConfig.spacing8),
            Container(
              padding: const EdgeInsets.all(AppConfig.spacing12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: MarkdownDescriptionText(
                text: transcribedText,
                selectable: false,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(TranscriptionAction.cancel),
          child: const Text('Cancel'),
        ),
        // Append-only: when there's existing text we add to it; when empty it
        // just becomes the text ("Add"). No destructive replace option.
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(TranscriptionAction.append),
          child: Text(hasExistingDescription ? 'Append' : 'Add'),
        ),
      ],
    );
  }

  static Future<TranscriptionAction?> show(
    BuildContext context, {
    required String transcribedText,
    required bool hasExistingDescription,
  }) {
    return showDialog<TranscriptionAction>(
      context: context,
      builder: (context) => TranscriptionActionDialog(
        transcribedText: transcribedText,
        hasExistingDescription: hasExistingDescription,
      ),
    );
  }
}

