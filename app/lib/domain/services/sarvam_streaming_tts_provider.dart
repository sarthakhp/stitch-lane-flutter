import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../utils/app_logger.dart';
import 'ai_gateway/ai_gateway.dart';
import 'ai_gateway/usage_event.dart';
import 'streaming_tts_provider.dart';

class SarvamStreamingTtsProvider implements StreamingTtsProvider {
  static const String _baseWsUrl = 'wss://api.sarvam.ai/text-to-speech/ws';

  WebSocketChannel? _channel;
  final _audioController = StreamController<TtsAudioChunk>.broadcast();
  final _eventController = StreamController<StreamingTtsEventData>.broadcast();
  bool _isConnected = false;

  // ─── Usage tracking ──────────────────────────────────────────────────────
  DateTime? _sessionStart;
  String? _runId;
  String? _modelName;
  int _totalChars = 0;
  bool _recorded = false;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<TtsAudioChunk> get audioChunks => _audioController.stream;

  @override
  Stream<StreamingTtsEventData> get events => _eventController.stream;

  @override
  Future<void> connect({TtsConfig config = const TtsConfig()}) async {
    final apiKey = dotenv.env['SARVAM_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('SARVAM_API_KEY not found in .env file');
    }

    final uri = Uri.parse(
      '$_baseWsUrl'
      '?model=${config.model}'
      '&send_completion_event=true',
    );

    AppLogger.info('Sarvam TTS: connecting to $uri');

    try {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Api-Subscription-Key': apiKey},
      );

      await _channel!.ready;

      _isConnected = true;

      // Reset usage counters for this fresh session.
      _sessionStart = DateTime.now();
      _runId = const Uuid().v4();
      _modelName = config.model;
      _totalChars = 0;
      _recorded = false;

      _eventController.add(const StreamingTtsEventData(StreamingTtsEvent.connected));
      AppLogger.info('Sarvam TTS: connected');

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } on WebSocketChannelException catch (e) {
      _isConnected = false;
      AppLogger.error('Sarvam TTS: WebSocket connection failed', e);
      throw Exception('WebSocket connection failed: $e');
    } on SocketException catch (e) {
      _isConnected = false;
      AppLogger.error('Sarvam TTS: network error', e);
      throw Exception('Network error: $e');
    }
  }

  @override
  void sendConfig(TtsConfig config) {
    if (!_isConnected || _channel == null) return;

    final message = jsonEncode({
      'type': 'config',
      'data': config.toWsJson(),
    });

    AppLogger.info('Sarvam TTS: sending config');
    _channel!.sink.add(message);
  }

  @override
  void sendText(String textChunk) {
    if (!_isConnected || _channel == null) return;

    _totalChars += textChunk.length;

    final message = jsonEncode({
      'type': 'text',
      'data': {'text': textChunk},
    });

    AppLogger.info('Sarvam TTS: sending text (${textChunk.length} chars)');
    _channel!.sink.add(message);
  }

  @override
  void sendFlush() {
    if (!_isConnected || _channel == null) return;
    AppLogger.info('Sarvam TTS: sending flush');
    _channel!.sink.add(jsonEncode({'type': 'flush'}));
  }

  @override
  Future<void> close() async {
    AppLogger.info('Sarvam TTS: closing');
    _isConnected = false;
    _loggedFirstChunk = false;

    // Record before tearing down — close() is the most reliable hook for
    // caller-initiated shutdown. _onDone is a fallback for unexpected ones.
    await _recordSessionEvent();

    await _channel?.sink.close();
    _channel = null;

    await _audioController.close();
    await _eventController.close();
  }

  bool _loggedFirstChunk = false;

  void _onMessage(dynamic message) {
    if (message is! String) return;

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'audio':
          final data = json['data'] as Map<String, dynamic>? ?? {};
          final audioBase64 = data['audio'] as String?;
          final contentType = data['content_type'] as String? ?? 'audio/wav';
          if (audioBase64 != null && audioBase64.isNotEmpty) {
            final bytes = base64Decode(audioBase64);
            if (!_loggedFirstChunk) {
              _loggedFirstChunk = true;
              AppLogger.info('Sarvam TTS: first chunk — content_type=$contentType, bytes=${bytes.length}');
            }
            _audioController.add(TtsAudioChunk(
              audioBytes: Uint8List.fromList(bytes),
              contentType: contentType,
            ));
          }

        case 'event':
          AppLogger.info('Sarvam TTS: completion event received');
          _eventController.add(const StreamingTtsEventData(StreamingTtsEvent.completed));

        case 'error':
          final data = json['data'] as Map<String, dynamic>?;
          final errorMsg = data?['message'] as String? ?? json['message'] as String? ?? 'Unknown error';
          AppLogger.error('Sarvam TTS: server error: $errorMsg');
          _eventController.add(StreamingTtsEventData(
            StreamingTtsEvent.error,
            message: errorMsg,
          ));
      }
    } catch (e) {
      AppLogger.error('Sarvam TTS: failed to parse message', e);
    }
  }

  void _onError(dynamic error) {
    AppLogger.error('Sarvam TTS: WebSocket error', error);
    _isConnected = false;
    _eventController.add(StreamingTtsEventData(
      StreamingTtsEvent.error,
      message: error.toString(),
    ));
    unawaited(_recordSessionEvent(errorCode: 'ws_error'));
  }

  void _onDone() {
    AppLogger.info('Sarvam TTS: WebSocket closed');
    _isConnected = false;
    _eventController.add(const StreamingTtsEventData(StreamingTtsEvent.disconnected));
    unawaited(_recordSessionEvent());
  }

  /// Emits one [UsageEvent] for the whole session. Idempotent via [_recorded];
  /// safe to call from close(), _onError, and _onDone in any order.
  Future<void> _recordSessionEvent({String? errorCode}) async {
    if (_recorded) return;
    _recorded = true;

    final start = _sessionStart;
    final modelName = _modelName;
    if (start == null || modelName == null) return;

    final durationMs = DateTime.now().difference(start).inMilliseconds;

    await AiGateway.instance.recorder.recordCall(
      callerTag: UsageCallerTags.ttsStream,
      runId: _runId,
      provider: UsageProvider.sarvam,
      model: modelName,
      kind: UsageKind.tts,
      inputChars: _totalChars > 0 ? _totalChars : null,
      durationMs: durationMs,
      errorCode: errorCode,
    );
  }
}
