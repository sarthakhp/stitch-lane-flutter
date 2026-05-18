import 'package:flutter/material.dart';
import 'streaming_voice_input.dart';

class StreamingVoiceBottomSheet {
  static Future<String?> show(
    BuildContext context, {
    bool enableFormatting = true,
  }) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StreamingVoiceInput(
        enableFormatting: enableFormatting,
        onDone: (text) => Navigator.of(sheetContext).pop(text),
        onCancel: () => Navigator.of(sheetContext).pop(null),
      ),
    );
  }
}
