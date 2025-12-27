import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'markdown_description_text.dart';

enum TranscriptionAction {
  append,
  replace,
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
            if (hasExistingDescription) ...[
              const SizedBox(height: AppConfig.spacing16),
              Text(
                'How would you like to add this to the description?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(TranscriptionAction.cancel),
          child: const Text('Cancel'),
        ),
        if (hasExistingDescription)
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(TranscriptionAction.replace),
            child: const Text('Replace'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
                hasExistingDescription
                    ? TranscriptionAction.append
                    : TranscriptionAction.replace,
              ),
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

