import 'gemini_service.dart';
import '../../utils/app_logger.dart';

class FormatResult {
  final String? text;
  final bool failed;
  const FormatResult({this.text, this.failed = false});
}

/// Runs the raw transcript through the Gemini formatting agent.
/// Returns `text=null, failed=true` on any error so callers can render a
/// "use raw / retry" UI without losing the underlying transcript.
class TranscriptFormatter {
  static Future<FormatResult> format(
    String rawText, {
    String? modelName,
  }) async {
    if (rawText.isEmpty) return const FormatResult();

    try {
      final formatted = await GeminiService.formatTranscription(
        rawText,
        modelName: modelName,
      );
      if (formatted == null || formatted.isEmpty) {
        return const FormatResult(failed: true);
      }
      return FormatResult(text: formatted);
    } catch (e) {
      AppLogger.error('TranscriptFormatter: failed', e);
      return const FormatResult(failed: true);
    }
  }
}
