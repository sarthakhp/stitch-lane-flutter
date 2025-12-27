import 'dart:async';
import 'package:flutter/material.dart';
import 'gemini_service.dart';
import '../../presentation/widgets/transcription_progress_dialog.dart';
import '../../presentation/widgets/transcription_action_dialog.dart';

class TranscriptionService {
  static Future<String?> transcribeAndGetAction({
    required BuildContext context,
    required String audioFilePath,
    required String currentText,
  }) async {
    Completer<void>? transcriptionCompleter = Completer<void>();

    try {
      if (!context.mounted) return null;

      TranscriptionProgressDialog.show(
        context,
        onCancel: () {
          transcriptionCompleter?.complete();
          Navigator.of(context).pop();
        },
      );

      String? transcription;
      try {
        transcription = await GeminiService.transcribeAudio(audioFilePath);
      } catch (e) {
        if (!transcriptionCompleter.isCompleted) {
          transcriptionCompleter.complete();
        }
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return null;
      }

      if (!transcriptionCompleter.isCompleted) {
        transcriptionCompleter.complete();
      }

      if (!context.mounted) return null;
      Navigator.of(context).pop();

      if (transcription == null || transcription.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No transcription available'),
            duration: Duration(seconds: 2),
          ),
        );
        return null;
      }

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
    } finally {
      transcriptionCompleter = null;
    }
  }
}

