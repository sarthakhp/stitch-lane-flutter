import 'package:flutter/material.dart';
import 'streaming_voice_input.dart';

class StreamingVoiceBottomSheet {
  static Future<VoiceInputResult?> show(
    BuildContext context, {
    // Default off: the typical voice-input consumer is an LLM (chat agent,
    // order creator) that handles raw STT fine. Only persisted human-readable
    // fields (order / measurement / customer description) should opt in by
    // passing `enableFormatting: true`.
    bool enableFormatting = false,
    String? formattingModelName,
  }) {
    return showModalBottomSheet<VoiceInputResult?>(
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
        formattingModelName: formattingModelName,
        onDone: (result) => Navigator.of(sheetContext).pop(result),
        onCancel: () => Navigator.of(sheetContext).pop(null),
      ),
    );
  }
}
