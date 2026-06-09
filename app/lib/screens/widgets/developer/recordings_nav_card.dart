import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../recordings_screen.dart';

/// Entry-point card on the Developer screen that opens the Recordings browser
/// — every voice recording by date, with playback, transcript, and what the
/// AI did. The go-to place for debugging "she said it didn't work".
class RecordingsNavCard extends StatelessWidget {
  const RecordingsNavCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecordingsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.graphic_eq, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Recordings',
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Play back every voice recording with its transcript and '
                      'what the AI did.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
