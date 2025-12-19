import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are a professional transcription assistant for a tailoring and stitching business. '
        'Your task is to accurately transcribe audio recordings that contain garment measurements and stitching instructions. '
        'The audio may include measurements like Length, Bust, Waist, Hip, Shoulder, Armhole, Sleeve Length, Neck, etc. '
        'Transcribe numbers, measurements, and garment details clearly and accurately. '
        'Maintain proper formatting with clear separation between different measurements. '
        'The audio may be in English, Gujarati, or Hindi - transcribe in the same language spoken.'
        'Highest language preference is English, followed by Gujarati, and then Hindi when detecting language',
      ),
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

      final prompt = TextPart(
        'Transcribe this audio recording containing garment measurements and stitching instructions. '
        'Format the transcription clearly with proper punctuation and line breaks where appropriate. '
        'If measurements are mentioned (e.g., Length: 40 inches, Bust: 36 inches, Hip, Waist, Shoulder, Arm Hole etc.), format them clearly. '
        'Preserve all numbers, units, and measurement details accurately. '
        'Provide only the transcription without any additional commentary, explanations, or meta-text.'
        'If no one is speaking in the recording, respond: "No one is speaking".',
      );

      AppLogger.info('Prompt: ${prompt.text}');

      final audioPart = DataPart('audio/m4a', audioBytes);

      final response = await model.generateContent([
        Content.multi([prompt, audioPart])
      ]);

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

