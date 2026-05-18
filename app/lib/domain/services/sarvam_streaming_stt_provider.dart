import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../utils/app_logger.dart';
import 'streaming_stt_provider.dart';

class SarvamStreamingSttProvider implements StreamingSttProvider {
  static const String _baseWsUrl = 'wss://api.sarvam.ai/speech-to-text/ws';
  static const String _model = 'saaras:v3';
  static const Duration _flushTimeout = Duration(seconds: 5);

  final String languageCode;
  final String mode;
  final int sampleRate;

  WebSocketChannel? _channel;
  final _transcriptController = StreamController<StreamingTranscript>.broadcast();
  final _eventController = StreamController<StreamingSttEventData>.broadcast();
  bool _isConnected = false;

  SarvamStreamingSttProvider({
    this.languageCode = 'gu-IN',
    this.mode = 'codemix',
    this.sampleRate = 16000,
  });

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<StreamingTranscript> get transcripts => _transcriptController.stream;

  @override
  Stream<StreamingSttEventData> get events => _eventController.stream;

  @override
  Future<void> connect() async {
    final apiKey = dotenv.env['SARVAM_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('SARVAM_API_KEY not found in .env file');
    }

    final uri = Uri.parse(
      '$_baseWsUrl'
      '?language-code=$languageCode'
      '&model=$_model'
      '&mode=$mode'
      '&sample_rate=$sampleRate'
      '&flush_signal=true'
      '&vad_signals=true',
    );

    AppLogger.info('Sarvam Streaming: connecting to $uri');

    try {
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'Api-Subscription-Key': apiKey},
      );

      // Wait for the connection to be established
      await _channel!.ready;

      _isConnected = true;
      _eventController.add(const StreamingSttEventData(StreamingSttEvent.connected));
      AppLogger.info('Sarvam Streaming: connected');

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
    } on WebSocketChannelException catch (e) {
      _isConnected = false;
      AppLogger.error('Sarvam Streaming: WebSocket connection failed', e);
      throw Exception('WebSocket connection failed: $e');
    } on SocketException catch (e) {
      _isConnected = false;
      AppLogger.error('Sarvam Streaming: network error', e);
      throw Exception('Network error: $e');
    }
  }

  @override
  void sendAudio(Uint8List pcmChunk) {
    if (!_isConnected || _channel == null) return;

    final base64Audio = base64Encode(pcmChunk);
    final message = jsonEncode({
      'audio': {
        'data': base64Audio,
        'sample_rate': '$sampleRate',
        'encoding': 'audio/wav',
      },
    });

    _channel!.sink.add(message);
  }

  @override
  Future<void> flush() async {
    if (!_isConnected || _channel == null) return;

    AppLogger.info('Sarvam Streaming: sending flush');
    _channel!.sink.add(jsonEncode({'type': 'flush'}));

    try {
      await _transcriptController.stream
          .firstWhere((t) => t.isFinal)
          .timeout(_flushTimeout);
    } on TimeoutException {
      AppLogger.warning('Sarvam Streaming: flush timed out after ${_flushTimeout.inSeconds}s');
    }
  }

  @override
  void sendFlush() {
    if (!_isConnected || _channel == null) return;
    AppLogger.info('Sarvam Streaming: sending flush (fire-and-forget)');
    _channel!.sink.add(jsonEncode({'type': 'flush'}));
  }

  @override
  Future<void> close() async {
    AppLogger.info('Sarvam Streaming: closing');
    _isConnected = false;

    await _channel?.sink.close();
    _channel = null;

    await _transcriptController.close();
    await _eventController.close();
  }

  void _onMessage(dynamic message) {
    if (message is! String) return;

    AppLogger.info('Sarvam Streaming: raw response: $message');

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;

      switch (type) {
        case 'data':
          final data = json['data'] as Map<String, dynamic>? ?? {};
          final transcript = data['transcript'] as String? ?? '';
          if (transcript.isNotEmpty) {
            _transcriptController.add(StreamingTranscript(
              text: transcript,
              isFinal: true,
              languageCode: data['language_code'] as String?,
            ));
          }

        case 'events':
          final data = json['data'] as Map<String, dynamic>? ?? {};
          final signalType = data['signal_type'] as String?;
          if (signalType == 'START_SPEECH') {
            _eventController.add(const StreamingSttEventData(StreamingSttEvent.startSpeech));
          } else if (signalType == 'END_SPEECH') {
            _eventController.add(const StreamingSttEventData(StreamingSttEvent.endSpeech));
          }

        case 'error':
          final data = json['data'] as Map<String, dynamic>? ?? {};
          final errorMsg = data['message'] as String? ?? data['error'] as String? ?? 'Unknown error';
          AppLogger.error('Sarvam Streaming: server error: $errorMsg');
          _eventController.add(StreamingSttEventData(
            StreamingSttEvent.error,
            message: errorMsg,
          ));
      }
    } catch (e) {
      AppLogger.error('Sarvam Streaming: failed to parse message: $message', e);
    }
  }

  void _onError(dynamic error) {
    AppLogger.error('Sarvam Streaming: WebSocket error', error);
    _isConnected = false;
    _eventController.add(StreamingSttEventData(
      StreamingSttEvent.error,
      message: error.toString(),
    ));
  }

  void _onDone() {
    AppLogger.info('Sarvam Streaming: WebSocket closed');
    _isConnected = false;
    _eventController.add(const StreamingSttEventData(StreamingSttEvent.disconnected));
  }
}
