import 'gemini_service.dart';
import 'stt_provider.dart';
import 'ai_chat_config.dart';

class GeminiSttProvider implements SttProvider {
  final String? systemInstruction;
  final String? transcriptionPrompt;
  final String modelName;

  GeminiSttProvider({
    this.systemInstruction,
    this.transcriptionPrompt,
    this.modelName = defaultAiFormattingModel,
  });

  @override
  Future<String?> transcribe(String audioFilePath) {
    return GeminiService.transcribeAudio(
      audioFilePath,
      systemInstruction: systemInstruction,
      transcriptionPrompt: transcriptionPrompt,
      modelName: modelName,
    );
  }
}
