import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final bool destructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    );
  }

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        destructive: destructive,
      ),
    );
    return result ?? false;
  }

  /// Two-step confirmation for irreversible actions — the user must confirm
  /// twice. Returns true only if both dialogs are confirmed.
  static Future<bool> showDouble({
    required BuildContext context,
    required String title,
    required String content,
    required String secondTitle,
    required String secondContent,
    String confirmText = 'Continue',
    String finalConfirmText = 'Delete',
    String cancelText = 'Cancel',
    bool destructive = true,
  }) async {
    final first = await show(
      context: context,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      destructive: destructive,
    );
    if (!first || !context.mounted) return false;

    return show(
      context: context,
      title: secondTitle,
      content: secondContent,
      confirmText: finalConfirmText,
      cancelText: cancelText,
      destructive: destructive,
    );
  }
}

