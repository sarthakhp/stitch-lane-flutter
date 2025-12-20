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
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are a professional transcription assistant for a tailoring and stitching business. '
        'The audio may be in English or Gujarati - transcribe in the same language spoken.'
        'Highest language preference is English, then Gujarati when detecting language',
      ),
    );

    return _model!;
  }

  static Future<String?> transcribeAudio(String audioFilePath) async {
    return _transcribe(
      audioFilePath: audioFilePath,
      prompt: 'Transcribe and Format this audio recording containing garment measurements and stitching instructions. '
          'The audio may include measurements like Length, Bust, Waist, Hip, Shoulder, Armhole, Sleeve Length, Neck, etc.\n\n'
          'CRITICAL FORMATTING RULES:\n'
          '1. ALWAYS put each measurement on a NEW LINE\n'
          '2. ALWAYS use this exact format for each measurement:\n'
          '   MeasurementName: Value Unit\n'
          '3. NEVER combine multiple measurements on the same line\n'
          '4. Use a blank line between different sections if needed\n\n'
          'EXAMPLE OUTPUT FORMAT:\n'
          'Length: 40 inches\n'
          'Bust: 36 inches\n'
          'Waist: 32 inches\n'
          'Hip: 38 inches\n\n'
          'NUMBER CONVERSION RULES:\n'
          '- "10 and half" or "10 and a half" → write as "10.5"\n'
          '- "15 and quarter" or "15 and a quarter" → write as "15.25"\n'
          '- "20 and three quarters" → write as "20.75"\n'
          '- Any similar conversational fractions → convert to decimal equivalents\n\n'
          'IMPORTANT:\n'
          '- Preserve all numbers, units, and measurement details accurately\n'
          '- Use proper punctuation\n'
          '- Each measurement MUST be on its own line\n'
          '- Provide only the transcription without any additional commentary, explanations, or meta-text\n'
          '- If no one is speaking in the recording, respond: "No one is speaking"',
    );
  }

  static Future<String?> transcribeOrderAudio(String audioFilePath) async {
    return _transcribe(
      audioFilePath: audioFilePath,
      prompt: 'Transcribe this audio recording containing order details, garment descriptions, and customer requirements. '
          'IMPORTANT: Format the transcription clearly with proper punctuation and use line breaks as much as possible.'
          'Include details about garment types, styles, colors, fabrics, special instructions, and any customer preferences. '
          'Preserve all specific details, numbers, and requirements accurately. '
          'Provide only the transcription without any additional commentary, explanations, or meta-text.'
          'If no one is speaking in the recording, respond: "No one is speaking".',
    );
  }

  static Future<String?> _transcribe({
    required String audioFilePath,
    required String prompt,
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

      final promptPart = TextPart(prompt);

      AppLogger.info('Prompt: $prompt');

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

