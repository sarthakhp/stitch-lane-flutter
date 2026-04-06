import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import '../../constants/gemini_prompts.dart';
import '../../utils/app_logger.dart';

class GeminiService {
  static ChatGoogleGenerativeAI? _model;

  static ChatGoogleGenerativeAI _getModel() {
    if (_model != null) return _model!;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw Exception(
        'GEMINI_API_KEY not found in .env file. '
        'Please add your API key from https://aistudio.google.com/app/apikey',
      );
    }

    _model = ChatGoogleGenerativeAI(
      apiKey: apiKey,
      defaultOptions: const ChatGoogleGenerativeAIOptions(
        model: 'gemini-3.1-flash-lite-preview',
      ),
    );

    return _model!;
  }

  static Future<String?> transcribeAudio(
    String audioFilePath, {
    String? systemInstruction,
    String? transcriptionPrompt,
  }) async {
    try {
      AppLogger.info('Starting audio transcription for: $audioFilePath');

      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        AppLogger.error('Audio file not found: $audioFilePath');
        throw Exception('Audio file not found');
      }

      final audioBytes = await audioFile.readAsBytes();
      AppLogger.info('Audio file size: ${audioBytes.length} bytes');

      final model = _getModel();
      final audioBase64 = base64Encode(audioBytes);

      final system = systemInstruction ?? GeminiPrompts.systemInstruction;
      final prompt = transcriptionPrompt ?? GeminiPrompts.transcriptionPrompt;

      final response = await model.invoke(
        PromptValue.chat([
          ChatMessage.system(system),
          ChatMessage.human(
            ChatMessageContent.multiModal([
              ChatMessageContent.text(prompt),
              ChatMessageContent.image(
                data: audioBase64,
                mimeType: 'audio/m4a',
              ),
            ]),
          ),
        ]),
      );

      final transcription = response.output.content;
      AppLogger.info('Response: $transcription');

      if (transcription.isEmpty) {
        AppLogger.warning('Gemini returned empty transcription');
        return null;
      }

      AppLogger.info('Transcription successful: ${transcription.length} characters');
      return transcription;
    } on SocketException catch (e) {
      AppLogger.error('Network error during transcription', e);
      throw Exception('No internet connection. Please check your network');
    } catch (e) {
      AppLogger.error('Unexpected error during transcription', e);
      throw Exception('Transcription failed: $e');
    }
  }
}
