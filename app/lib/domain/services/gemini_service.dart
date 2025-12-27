import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../constants/gemini_prompts.dart';
import '../../utils/app_logger.dart';

class GeminiService {
  static GenerativeModel? _model;

  static GenerativeModel _getModel() {
    if (_model != null) return _model!;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw Exception(
        'GEMINI_API_KEY not found in .env file. '
        'Please add your API key from https://aistudio.google.com/app/apikey',
      );
    }

    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
      systemInstruction: Content.system(GeminiPrompts.systemInstruction),
    );

    return _model!;
  }

  static Future<String?> transcribeAudio(String audioFilePath) async {
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

      final promptPart = TextPart(GeminiPrompts.transcriptionPrompt);

      final audioPart = DataPart('audio/m4a', audioBytes);

      final response = await model.generateContent([
        Content.multi([promptPart, audioPart])
      ]);

      AppLogger.info('Response: ${response.text}');

      if (response.text == null || response.text!.isEmpty) {
        AppLogger.warning('Gemini returned empty transcription');
        return null;
      }

      final transcription = response.text!;
      AppLogger.info('Transcription successful: ${transcription.length} characters');

      return transcription;
    } on GenerativeAIException catch (e) {
      AppLogger.error('Gemini API error during transcription', e);
      if (e.message.contains('API key')) {
        throw Exception('Invalid API key. Please check your GEMINI_API_KEY in .env file');
      } else if (e.message.contains('quota') || e.message.contains('limit')) {
        throw Exception('API quota exceeded. Please try again later');
      } else if (e.message.contains('network') || e.message.contains('connection')) {
        throw Exception('Network error. Please check your internet connection');
      }
      throw Exception('Transcription failed: ${e.message}');
    } on SocketException catch (e) {
      AppLogger.error('Network error during transcription', e);
      throw Exception('No internet connection. Please check your network');
    } catch (e) {
      AppLogger.error('Unexpected error during transcription', e);
      throw Exception('Transcription failed: $e');
    }
  }
}

