import 'package:flutter/material.dart';
import '../connectivity_guard.dart';
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
    String? formattingPromptOverride,
  }) async {
    // Pre-flight: every voice flow needs the network up front — live STT
    // streams immediately, and batch STT records locally but can't transcribe
    // offline. Gating here, the single shared entry point, means the user
    // learns they're offline BEFORE recording a whole message rather than
    // after tapping Done.
    final online = await ConnectivityGuard.ensureOnline(context);
    if (!online || !context.mounted) return null;

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
        formattingPromptOverride: formattingPromptOverride,
        onDone: (result) => Navigator.of(sheetContext).pop(result),
        onCancel: () => Navigator.of(sheetContext).pop(null),
      ),
    );
  }
}
