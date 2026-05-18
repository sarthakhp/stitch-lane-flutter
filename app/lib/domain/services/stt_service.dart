import '../../backend/models/app_settings.dart';
import '../../constants/gemini_prompts.dart';
import 'gemini_stt_provider.dart';
import 'sarvam_stt_provider.dart';
import 'stt_provider.dart';

const String sttProviderGemini = 'gemini';
const String sttProviderSarvam = 'sarvam';
const String defaultSttProvider = sttProviderGemini;

class SttService {
  static Future<String?> transcribe(
    String audioFilePath, {
    required AppSettings settings,
    String? systemInstruction,
    String? transcriptionPrompt,
  }) async {
    final provider = buildProvider(
      settings,
      systemInstruction: systemInstruction,
      transcriptionPrompt: transcriptionPrompt,
    );
    return provider.transcribe(audioFilePath);
  }

  static SttProvider buildProvider(
    AppSettings settings, {
    String? systemInstruction,
    String? transcriptionPrompt,
  }) {
    switch (settings.sttProvider) {
      case sttProviderSarvam:
        return SarvamSttProvider();
      case sttProviderGemini:
      default:
        return GeminiSttProvider(
          systemInstruction: systemInstruction ?? GeminiPrompts.systemInstruction,
          transcriptionPrompt: transcriptionPrompt ?? GeminiPrompts.transcriptionPrompt,
          modelName: settings.aiVoiceModel,
        );
    }
  }
}
