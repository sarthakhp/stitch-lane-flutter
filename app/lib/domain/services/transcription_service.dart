import 'package:flutter/material.dart';
import 'gemini_service.dart';
import '../../presentation/widgets/transcription_progress_dialog.dart';
import '../../presentation/widgets/transcription_action_dialog.dart';

enum TranscriptionResultType { success, error, cancelled }

class TranscriptionResult {
  final TranscriptionResultType type;
  final String? text;
  final String? errorMessage;

  const TranscriptionResult._(this.type, {this.text, this.errorMessage});

  factory TranscriptionResult.success(String text) =>
      TranscriptionResult._(TranscriptionResultType.success, text: text);

  factory TranscriptionResult.error(String message) =>
      TranscriptionResult._(TranscriptionResultType.error, errorMessage: message);

  factory TranscriptionResult.cancelled() =>
      const TranscriptionResult._(TranscriptionResultType.cancelled);
}

class TranscriptionService {
  /// Transcribes audio and returns a result indicating success, error, or cancellation.
  /// Does NOT show error UI — the caller is responsible for handling errors.
  static Future<TranscriptionResult> transcribe({
    required BuildContext context,
    required String audioFilePath,
    String? systemInstruction,
    String? transcriptionPrompt,
  }) async {
    bool isCancelled = false;

    if (!context.mounted) return TranscriptionResult.cancelled();

    TranscriptionProgressDialog.show(
      context,
      onCancel: () {
        isCancelled = true;
        Navigator.of(context).pop();
      },
    );

    String? transcription;
    try {
      transcription = await GeminiService.transcribeAudio(
        audioFilePath,
        systemInstruction: systemInstruction,
        transcriptionPrompt: transcriptionPrompt,
      );
    } catch (e) {
      if (context.mounted && !isCancelled) {
        Navigator.of(context).pop();
      }
      if (isCancelled) return TranscriptionResult.cancelled();
      return TranscriptionResult.error(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }

    if (isCancelled) return TranscriptionResult.cancelled();

    if (!context.mounted) return TranscriptionResult.cancelled();
    Navigator.of(context).pop();

    if (transcription == null || transcription.isEmpty) {
      return TranscriptionResult.error('No transcription available');
    }

    return TranscriptionResult.success(transcription);
  }

  /// Shows the action dialog (Replace/Append/Cancel) and returns the final text.
  static Future<String?> getActionResult({
    required BuildContext context,
    required String transcription,
    required String currentText,
  }) async {
    final hasExistingText = currentText.trim().isNotEmpty;

    final action = await TranscriptionActionDialog.show(
      context,
      transcribedText: transcription,
      hasExistingDescription: hasExistingText,
    );

    if (action == null || action == TranscriptionAction.cancel) {
      return null;
    }

    if (action == TranscriptionAction.replace) {
      return transcription;
    } else if (action == TranscriptionAction.append) {
      final trimmedCurrent = currentText.trim();
      return trimmedCurrent.isEmpty
          ? transcription
          : '$trimmedCurrent\n\n$transcription';
    }

    return null;
  }
}
