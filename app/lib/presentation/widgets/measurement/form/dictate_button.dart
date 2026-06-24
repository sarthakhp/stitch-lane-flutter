import 'package:flutter/material.dart';

import '../../../../config/app_config.dart';

/// Full-width "Dictate measurements" button; shows a spinner + "Organizing…"
/// while a dictation is being turned into structure.
class DictateButton extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const DictateButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppConfig.buttonBorderRadius),
          border: Border.all(color: colorScheme.primary, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              )
            else
              Icon(Icons.mic, size: 22, color: colorScheme.onPrimaryContainer),
            const SizedBox(width: AppConfig.spacing8),
            Text(
              busy ? 'Organizing…' : 'Dictate measurements',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
