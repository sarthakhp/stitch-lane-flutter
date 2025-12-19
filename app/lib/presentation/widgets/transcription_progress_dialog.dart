import 'package:flutter/material.dart';
import '../../config/app_config.dart';

class TranscriptionProgressDialog extends StatelessWidget {
  final VoidCallback onCancel;

  const TranscriptionProgressDialog({
    super.key,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppConfig.spacing24),
            Text(
              'Transcribing audio...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConfig.spacing8),
            Text(
              'This may take a few moments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required VoidCallback onCancel,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (context) => TranscriptionProgressDialog(
        onCancel: onCancel,
      ),
    );
  }
}

