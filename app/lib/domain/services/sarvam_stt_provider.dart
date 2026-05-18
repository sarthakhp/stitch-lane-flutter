import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_logger.dart';
import 'stt_provider.dart';

class SarvamSttProvider implements SttProvider {
  static const String _baseUrl = 'https://api.sarvam.ai';
  static const String _model = 'saaras:v3';

  final String languageCode;
  final String mode;

  SarvamSttProvider({
    this.languageCode = 'gu-IN',
    this.mode = 'codemix',
  });

  @override
  Future<String?> transcribe(String audioFilePath) async {
    final apiKey = dotenv.env['SARVAM_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('SARVAM_API_KEY not found in .env file');
    }

    final audioFile = File(audioFilePath);
    if (!await audioFile.exists()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    AppLogger.info('Sarvam STT: starting transcription for $audioFilePath');

    final uri = Uri.parse('$_baseUrl/speech-to-text');
    final request = http.MultipartRequest('POST', uri)
      ..headers['api-subscription-key'] = apiKey
      ..fields['model'] = _model
      ..fields['language_code'] = languageCode
      ..fields['mode'] = mode
      ..fields['with_timestamps'] = 'false'
      ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      AppLogger.error(
        'Sarvam STT: API error ${streamedResponse.statusCode}: $responseBody',
      );
      throw Exception('Sarvam transcription failed (${streamedResponse.statusCode})');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final transcript = json['transcript'] as String? ?? '';

    if (transcript.isEmpty) {
      AppLogger.warning('Sarvam STT: empty transcript returned');
      return null;
    }

    AppLogger.info('Sarvam STT: transcription successful (${transcript.length} chars)');
    return transcript;
  }
}
