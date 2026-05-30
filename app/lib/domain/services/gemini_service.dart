import 'dart:convert';
import 'dart:io' show File, SocketException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleai_dart/googleai_dart.dart' hide File;
import '../../constants/gemini_prompts.dart';
import '../../utils/app_logger.dart';
import 'ai_chat_config.dart';
import 'ai_gateway/ai_gateway.dart';
import 'ai_gateway/usage_event.dart';

class GeminiService {
  static GoogleAIClient? _client;

  static GoogleAIClient _getClient() {
    if (_client != null) return _client!;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      throw Exception(
        'GEMINI_API_KEY not found in .env file. '
        'Please add your API key from https://aistudio.google.com/app/apikey',
      );
    }

    _client = GoogleAIClient(
      config: GoogleAIConfig(authProvider: ApiKeyProvider(apiKey)),
    );
    return _client!;
  }

  /// Pick the right MIME type for the inline audio blob. Gemini's
  /// generateContent rejects requests whose declared mimeType doesn't match
  /// the actual bytes — historically this method hardcoded audio/m4a which
  /// broke the WAV files coming out of the streaming voice input pipeline.
  static String _mimeForAudioPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mp3';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/m4a';
  }

  static GenerationConfig _buildGenerationConfig(String modelName) {
    if (modelName.startsWith('gemini-3')) {
      AppLogger.info('GenerationConfig: model=$modelName, thinkingLevel=MINIMAL');
      return const GenerationConfig(
        thinkingConfig: ThinkingConfig(thinkingLevel: ThinkingLevel.minimal),
      );
    }
    AppLogger.info('GenerationConfig: model=$modelName, thinkingBudget=0');
    return const GenerationConfig(
      thinkingConfig: ThinkingConfig(thinkingBudget: 0),
    );
  }

  static Future<String?> transcribeAudio(
    String audioFilePath, {
    String? systemInstruction,
    String? transcriptionPrompt,
    String modelName = defaultAiFormattingModel,
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

      final client = _getClient();
      final audioBase64 = base64Encode(audioBytes);

      final system = systemInstruction ?? GeminiPrompts.systemInstruction;
      final prompt = transcriptionPrompt ?? GeminiPrompts.transcriptionPrompt;

      final mimeType = _mimeForAudioPath(audioFilePath);
      final response = await _generateContentWithRecording(
        client: client,
        modelName: modelName,
        request: GenerateContentRequest(
          systemInstruction: Content(
            parts: [TextPart(system)],
          ),
          contents: [
            Content.user([
              TextPart(prompt),
              InlineDataPart(Blob(mimeType: mimeType, data: audioBase64)),
            ]),
          ],
          generationConfig: _buildGenerationConfig(modelName),
        ),
        callerTag: UsageCallerTags.transcription,
        kind: UsageKind.multimodal,
      );

      final transcription = response.text;
      AppLogger.info('Response: $transcription');

      if (transcription == null || transcription.isEmpty) {
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

  static Future<String?> formatTranscription(
    String rawText, {
    String? systemInstruction,
    String? formattingPrompt,
    String? modelName,
  }) async {
    modelName ??= defaultAiFormattingModel;
    try {
      AppLogger.info('Formatting transcription (${rawText.length} chars)');
      AppLogger.info('Formatting INPUT:\n$rawText');

      final client = _getClient();
      final system = systemInstruction ?? GeminiPrompts.formattingSystemInstruction;
      final prompt = formattingPrompt ?? GeminiPrompts.formattingPrompt;

      final response = await _generateContentWithRecording(
        client: client,
        modelName: modelName,
        request: GenerateContentRequest(
          systemInstruction: Content(
            parts: [TextPart(system)],
          ),
          contents: [
            Content.user([
              TextPart('$prompt\n\nINPUT:\n$rawText'),
            ]),
          ],
          generationConfig: _buildGenerationConfig(modelName),
        ),
        callerTag: UsageCallerTags.transcriptFormat,
        kind: UsageKind.chat,
      );

      final formatted = response.text;

      if (formatted == null || formatted.isEmpty) {
        AppLogger.warning('Gemini returned empty formatting result');
        return null;
      }

      AppLogger.info('Formatting OUTPUT:\n$formatted');
      return formatted;
    } on SocketException catch (e) {
      AppLogger.error('Network error during formatting', e);
      throw Exception('No internet connection. Please check your network');
    } catch (e) {
      AppLogger.error('Formatting failed', e);
      throw Exception('Formatting failed: $e');
    }
  }

  /// Wraps a `client.models.generateContent` call with a stopwatch and emits
  /// a [UsageEvent] on both success and failure (then rethrows). Token counts
  /// are extracted from the `usageMetadata` field of [googleai_dart]'s
  /// `GenerateContentResponse`, normalized to nullable ints — the gateway's
  /// pricing path handles missing values.
  static Future<GenerateContentResponse> _generateContentWithRecording({
    required GoogleAIClient client,
    required String modelName,
    required GenerateContentRequest request,
    required String callerTag,
    required UsageKind kind,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final response = await client.models.generateContent(
        model: modelName,
        request: request,
      );
      sw.stop();
      final u = response.usageMetadata;
      await AiGateway.instance.recorder.recordCall(
        callerTag: callerTag,
        provider: UsageProvider.gemini,
        model: modelName,
        kind: kind,
        inputTokens: u?.promptTokenCount,
        outputTokens: u?.candidatesTokenCount,
        totalTokens: u?.totalTokenCount,
        durationMs: sw.elapsedMilliseconds,
      );
      return response;
    } catch (e) {
      sw.stop();
      final code = e is SocketException ? 'network' : 'error';
      await AiGateway.instance.recorder.recordCall(
        callerTag: callerTag,
        provider: UsageProvider.gemini,
        model: modelName,
        kind: kind,
        durationMs: sw.elapsedMilliseconds,
        errorCode: code,
      );
      rethrow;
    }
  }
}
