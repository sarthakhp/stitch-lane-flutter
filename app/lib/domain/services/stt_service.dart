import '../../backend/models/app_settings.dart';
import '../../constants/gemini_prompts.dart';
import 'gemini_stt_provider.dart';
import 'sarvam_stt_provider.dart';
import 'stt_provider.dart';

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
    final sttModel = settings.sttModel;
    final colonIndex = sttModel.indexOf(':');
    final providerPrefix = colonIndex > 0 ? sttModel.substring(0, colonIndex) : sttModel;
    final modelName = colonIndex > 0 ? sttModel.substring(colonIndex + 1) : '';

    switch (providerPrefix) {
      case 'sarvam':
        return SarvamSttProvider(model: modelName.isNotEmpty ? modelName : 'saaras:v3');
      case 'gemini':
        return GeminiSttProvider(
          systemInstruction: systemInstruction ?? GeminiPrompts.systemInstruction,
          transcriptionPrompt: transcriptionPrompt ?? GeminiPrompts.transcriptionPrompt,
          modelName: modelName.isNotEmpty ? modelName : 'gemini-2.5-flash-lite',
        );
      default:
        return SarvamSttProvider();
    }
  }
}
