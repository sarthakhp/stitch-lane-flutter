import 'dart:async';
import 'dart:typed_data';
import '../../utils/app_logger.dart';
import 'sarvam_streaming_stt_provider.dart';
import 'streaming_recording_service.dart';
import 'streaming_stt_provider.dart';

class StreamingTranscriptionService {
  // 300ms @ 16kHz, 16-bit mono = 9600 bytes. Used to warm up the server-side
  // recognizer on connect so the first real syllable doesn't get clipped.
  static const int _warmupSilenceBytes = 9600;

  /// Optional hook for every real-mic chunk before it goes to the STT
  /// provider. Used by the controller to write a fail-safe local recording.
  /// Synthetic chunks (warm-up silence) are NOT passed through this hook.
  void Function(Uint8List chunk)? onAudioChunk;

  StreamingRecordingService? _recorder;
  StreamingSttProvider? _provider;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<StreamingTranscript>? _transcriptSubscription;

  final _transcriptController = StreamController<StreamingTranscript>.broadcast();
  final _eventController = StreamController<StreamingSttEventData>.broadcast();

  final StringBuffer _accumulatedTranscript = StringBuffer();
  bool _isActive = false;

  bool get isActive => _isActive;

  StreamingRecordingService? get recorder => _recorder;

  String get currentTranscript => _accumulatedTranscript.toString();

  Stream<StreamingTranscript> get transcripts => _transcriptController.stream;

  Stream<StreamingSttEventData> get events => _eventController.stream;

  Future<void> start() async {
    if (_isActive) {
      throw StateError('Streaming session already active');
    }

    AppLogger.info('StreamingTranscription: starting session');

    _recorder = StreamingRecordingService();
    _provider = SarvamStreamingSttProvider();

    try {
      await _provider!.connect();

      // Warm up the server-side recognizer before real mic audio arrives.
      _provider!.sendAudio(Uint8List(_warmupSilenceBytes));

      _transcriptSubscription = _provider!.transcripts.listen((transcript) {
        if (transcript.text.isNotEmpty) {
          if (transcript.isFinal) {
            if (_accumulatedTranscript.isNotEmpty) {
              _accumulatedTranscript.write(' ');
            }
            _accumulatedTranscript.write(transcript.text);
          }
          _transcriptController.add(transcript);
        }
      });

      _provider!.events.listen((event) {
        _eventController.add(event);
      });

      final audioStream = await _recorder!.startStream();
      _audioSubscription = audioStream.listen((chunk) {
        // Backup FIRST, before anything that can throw or drop the chunk.
        // The local recording is our last-resort safety net for the user.
        try {
          onAudioChunk?.call(chunk);
        } catch (e) {
          AppLogger.error('StreamingTranscription: onAudioChunk hook threw', e);
        }
        _provider?.sendAudio(chunk);
      });

      _isActive = true;
      AppLogger.info('StreamingTranscription: session active');
    } catch (e) {
      AppLogger.error('StreamingTranscription: failed to start', e);
      await _cleanup();
      rethrow;
    }
  }

  Future<void> pauseAudio() async {
    AppLogger.info('StreamingTranscription: pausing audio');
    await _recorder?.pause();
  }

  Future<void> resumeAudio() async {
    AppLogger.info('StreamingTranscription: resuming audio');
    await _recorder?.resume();
  }

  void sendFlush() {
    _provider?.sendFlush();
  }

  Future<String?> stop() async {
    if (!_isActive) return null;

    AppLogger.info('StreamingTranscription: stopping session');

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // Fire-and-forget flush — tells server to finalize any remaining buffer
    _provider?.sendFlush();

    // Brief grace period for last transcripts to arrive
    await Future.delayed(const Duration(milliseconds: 1500));

    await _recorder?.stop();
    await _provider?.close();

    _isActive = false;

    final result = _accumulatedTranscript.toString().trim();
    AppLogger.info('StreamingTranscription: final transcript (${result.length} chars)');

    return result.isEmpty ? null : result;
  }

  Future<void> cancel() async {
    AppLogger.info('StreamingTranscription: cancelling');
    await _cleanup();
  }

  Future<void> dispose() async {
    await _cleanup();
    await _transcriptController.close();
    await _eventController.close();
  }

  Future<void> _cleanup() async {
    _isActive = false;

    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _transcriptSubscription?.cancel();
    _transcriptSubscription = null;

    await _recorder?.dispose();
    _recorder = null;

    try {
      await _provider?.close();
    } catch (_) {}
    _provider = null;

    _accumulatedTranscript.clear();
  }
}
