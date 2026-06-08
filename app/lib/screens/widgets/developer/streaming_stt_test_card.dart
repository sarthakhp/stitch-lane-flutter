import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_config.dart';
import '../../../domain/domain.dart';
import '../../../presentation/presentation.dart';
import '../../../presentation/widgets/streaming_stt_test_dialog.dart';

/// Developer-only tools to exercise the streaming STT path (Sarvam WebSocket):
/// a test dialog and the reusable voice bottom sheet.
class StreamingSttTestCard extends StatelessWidget {
  const StreamingSttTestCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stream, color: theme.colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text('Streaming STT', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppConfig.spacing12),
            Text(
              'Test real-time transcription via Sarvam WebSocket',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConfig.spacing12),
            Wrap(
              spacing: AppConfig.spacing8,
              runSpacing: AppConfig.spacing8,
              children: [
                FilledButton.icon(
                  onPressed: () => StreamingSttTestDialog.show(context),
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Streaming'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    final formattingModel = context.read<SettingsState>().settings.aiFormattingModel;
                    final result = await StreamingVoiceBottomSheet.show(
                      context,
                      formattingModelName: formattingModel,
                    );
                    if (context.mounted && result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.audioWavPath != null
                                ? 'Got: ${result.text}\nAudio: ${result.audioWavPath}'
                                : 'Got: ${result.text}',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Bottom Sheet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
