import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../utils/app_logger.dart';
import 'ai_gateway/ai_gateway.dart';
import 'ai_gateway/audio_duration_probe.dart';
import 'ai_gateway/usage_event.dart';
import 'stt_provider.dart';

class SarvamSttProvider implements SttProvider {
  static const String _baseUrl = 'https://api.sarvam.ai';

  final String model;
  final String languageCode;
  final String mode;

  SarvamSttProvider({
    this.model = 'saaras:v3',
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

    // Probe duration BEFORE the network call. Sarvam bills per audio second
    // and doesn't return the duration in its response, so we measure it
    // client-side. A null result here just means cost won't compute — the
    // request itself is still recorded.
    final audioInputMs = await AudioDurationProbe.probeMs(audioFilePath);

    final uri = Uri.parse('$_baseUrl/speech-to-text');
    final request = http.MultipartRequest('POST', uri)
      ..headers['api-subscription-key'] = apiKey
      ..fields['model'] = model
      ..fields['language_code'] = languageCode
      ..fields['mode'] = mode
      ..fields['with_timestamps'] = 'false'
      ..files.add(await http.MultipartFile.fromPath('file', audioFilePath));

    // Three recording paths below: (1) network exception in the catch,
    // (2) HTTP non-200 after the try, (3) success. Each is explicit — no
    // shared "already recorded" sentinel needed.
    final sw = Stopwatch()..start();

    http.StreamedResponse streamedResponse;
    String responseBody;
    try {
      streamedResponse = await request.send();
      responseBody = await streamedResponse.stream.bytesToString();
    } catch (e) {
      sw.stop();
      final code = e is TimeoutException
          ? 'timeout'
          : e is SocketException
              ? 'network'
              : 'error';
      await AiGateway.instance.recorder.recordCall(
        callerTag: UsageCallerTags.sttBatch,
        provider: UsageProvider.sarvam,
        model: model,
        kind: UsageKind.stt,
        audioInputMs: audioInputMs,
        durationMs: sw.elapsedMilliseconds,
        errorCode: code,
      );
      rethrow;
    }
    sw.stop();

    if (streamedResponse.statusCode != 200) {
      AppLogger.error(
        'Sarvam STT: API error ${streamedResponse.statusCode}: $responseBody',
      );
      await AiGateway.instance.recorder.recordCall(
        callerTag: UsageCallerTags.sttBatch,
        provider: UsageProvider.sarvam,
        model: model,
        kind: UsageKind.stt,
        audioInputMs: audioInputMs,
        durationMs: sw.elapsedMilliseconds,
        errorCode: 'http_${streamedResponse.statusCode}',
      );
      throw Exception(
          'Sarvam transcription failed (${streamedResponse.statusCode})');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final transcript = json['transcript'] as String? ?? '';

    // Record success — even if transcript is empty, the call still cost
    // money and the dashboard should reflect that.
    await AiGateway.instance.recorder.recordCall(
      callerTag: UsageCallerTags.sttBatch,
      provider: UsageProvider.sarvam,
      model: model,
      kind: UsageKind.stt,
      audioInputMs: audioInputMs,
      durationMs: sw.elapsedMilliseconds,
    );

    if (transcript.isEmpty) {
      AppLogger.warning('Sarvam STT: empty transcript returned');
      return null;
    }

    AppLogger.info('Sarvam STT: transcription successful (${transcript.length} chars)');
    return transcript;
  }
}
