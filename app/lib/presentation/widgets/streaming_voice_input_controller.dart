import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/services/gemini_service.dart';
import '../../domain/services/streaming_amplitude_tracker.dart';
import '../../domain/services/streaming_stt_provider.dart';
import '../../domain/services/streaming_transcription_service.dart';
import '../../utils/app_logger.dart';

enum VoiceInputState { connecting, listening, paused, processing, formatting, done, error }

class StreamingVoiceInputController extends ChangeNotifier {
  static const maxRecordingSeconds = 300; // 5 minutes
  static const _hardPauseDelaySeconds = 10;

  VoiceInputState _state = VoiceInputState.connecting;
  String _finalText = '';
  String _partialText = '';
  String? _formattedText;
  String? _errorMessage;
  bool _formattingFailed = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  Timer? _hardPauseTimer;
  bool _hardPaused = false;
  final bool enableFormatting;

  StreamingTranscriptionService _service = StreamingTranscriptionService();
  StreamingAmplitudeTracker? _amplitudeTracker;
  StreamSubscription<StreamingTranscript>? _transcriptSub;
  StreamSubscription<StreamingSttEventData>? _eventSub;

  StreamingVoiceInputController({this.enableFormatting = false});

  VoiceInputState get state => _state;
  String get finalText => _finalText;
  String get partialText => _partialText;
  String? get formattedText => _formattedText;
  bool get formattingFailed => _formattingFailed;
  String get displayText {
    if (_finalText.isEmpty && _partialText.isEmpty) return '';
    if (_partialText.isEmpty) return _finalText;
    if (_finalText.isEmpty) return _partialText;
    return '$_finalText $_partialText';
  }
  String? get errorMessage => _errorMessage;
  int get recordingSeconds => _recordingSeconds;
  List<double> get amplitudeLevels => _amplitudeTracker?.levels ?? List.filled(15, 0.0);

  Future<void> start() async {
    _state = VoiceInputState.connecting;
    notifyListeners();

    try {
      _transcriptSub = _service.transcripts.listen(_onTranscript);
      _eventSub = _service.events.listen(_onEvent);

      await _service.start();

      if (_service.recorder != null) {
        _amplitudeTracker = StreamingAmplitudeTracker(
          recorder: _service.recorder!,
          onUpdate: notifyListeners,
        );
        _amplitudeTracker!.start();
      }

      _state = VoiceInputState.listening;
      _startRecordingTimer();
      notifyListeners();
    } catch (e) {
      AppLogger.error('VoiceInputController: failed to start', e);
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = VoiceInputState.error;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_state != VoiceInputState.listening) return;

    // Immediately show paused state
    _stopRecordingTimer();
    _amplitudeTracker?.stop();
    _state = VoiceInputState.paused;
    _hardPaused = false;
    notifyListeners();

    // Soft pause: pause the mic, then tell server to finalize remaining buffer
    await _service.pauseAudio();
    _service.sendFlush();

    // Schedule hard pause after delay
    _hardPauseTimer?.cancel();
    _hardPauseTimer = Timer(
      const Duration(seconds: _hardPauseDelaySeconds),
      _performHardPause,
    );
  }

  Future<void> _performHardPause() async {
    if (_state != VoiceInputState.paused || _hardPaused) return;

    AppLogger.info('VoiceInputController: hard pause — closing stream');
    _hardPaused = true;

    _amplitudeTracker?.dispose();
    _amplitudeTracker = null;

    final segmentText = await _service.stop();
    if (segmentText != null && segmentText.isNotEmpty) {
      _finalText = segmentText;
    }
    _partialText = '';

    await _transcriptSub?.cancel();
    _transcriptSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _service.dispose();
  }

  Future<void> resume() async {
    if (_state != VoiceInputState.paused) return;

    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;

    if (!_hardPaused) {
      // Soft resume: just unpause the mic, same WebSocket
      await _service.resumeAudio();
      _amplitudeTracker?.start();
      _state = VoiceInputState.listening;
      _startRecordingTimer();
      notifyListeners();
      return;
    }

    // Hard resume: need full reconnect
    _state = VoiceInputState.connecting;
    notifyListeners();

    final savedText = _finalText;
    _service = StreamingTranscriptionService();

    try {
      _transcriptSub = _service.transcripts.listen(_onTranscript);
      _eventSub = _service.events.listen(_onEvent);

      await _service.start();

      if (_service.recorder != null) {
        _amplitudeTracker = StreamingAmplitudeTracker(
          recorder: _service.recorder!,
          onUpdate: notifyListeners,
        );
        _amplitudeTracker!.start();
      }

      _finalText = savedText;
      _state = VoiceInputState.listening;
      _startRecordingTimer();
      notifyListeners();
    } catch (e) {
      AppLogger.error('VoiceInputController: failed to resume', e);
      _finalText = savedText;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _state = VoiceInputState.error;
      notifyListeners();
    }
  }

  Future<String?> stop() async {
    _stopRecordingTimer();
    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;
    _amplitudeTracker?.stop();

    if (_state == VoiceInputState.paused && _hardPaused) {
      // Already flushed during hard pause
      return _finalize();
    }

    _state = VoiceInputState.processing;
    notifyListeners();

    final result = await _service.stop();
    _finalText = result ?? _finalText;
    _partialText = '';

    return _finalize();
  }

  Future<String?> _finalize() async {
    if (_finalText.isEmpty) {
      _state = VoiceInputState.done;
      notifyListeners();
      return null;
    }

    if (!enableFormatting) {
      _state = VoiceInputState.done;
      notifyListeners();
      return _finalText;
    }

    _state = VoiceInputState.formatting;
    _formattingFailed = false;
    notifyListeners();

    try {
      final formatted = await GeminiService.formatTranscription(_finalText);
      if (formatted != null && formatted.isNotEmpty) {
        _formattedText = formatted;
      } else {
        _formattedText = null;
        _formattingFailed = true;
      }
    } catch (e) {
      AppLogger.error('VoiceInputController: formatting failed', e);
      _formattedText = null;
      _formattingFailed = true;
    }

    _state = VoiceInputState.done;
    notifyListeners();

    return _formattedText ?? _finalText;
  }

  Future<String?> retryFormatting() async {
    if (_finalText.isEmpty) return null;

    _state = VoiceInputState.formatting;
    _formattingFailed = false;
    notifyListeners();

    try {
      final formatted = await GeminiService.formatTranscription(_finalText);
      if (formatted != null && formatted.isNotEmpty) {
        _formattedText = formatted;
        _formattingFailed = false;
      } else {
        _formattingFailed = true;
      }
    } catch (e) {
      AppLogger.error('VoiceInputController: retry formatting failed', e);
      _formattingFailed = true;
    }

    _state = VoiceInputState.done;
    notifyListeners();

    return _formattedText ?? _finalText;
  }

  Future<void> cancel() async {
    _stopRecordingTimer();
    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;
    _amplitudeTracker?.stop();
    if (_state == VoiceInputState.paused && _hardPaused) {
      return;
    }
    await _service.cancel();
  }

  Future<void> retry() async {
    _finalText = '';
    _partialText = '';
    _formattedText = null;
    _formattingFailed = false;
    _errorMessage = null;
    _recordingSeconds = 0;
    _hardPaused = false;
    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;
    await _service.cancel();
    _service = StreamingTranscriptionService();
    await start();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingSeconds++;
      notifyListeners();
      if (_recordingSeconds >= maxRecordingSeconds) {
        stop();
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  void _onTranscript(StreamingTranscript t) {
    if (t.text.isEmpty) return;

    if (t.isFinal) {
      if (_finalText.isNotEmpty) {
        _finalText += ' ';
      }
      _finalText += t.text;
      _partialText = '';
    } else {
      _partialText = t.text;
    }
    notifyListeners();
  }

  void _onEvent(StreamingSttEventData e) {
    switch (e.event) {
      case StreamingSttEvent.error:
        _errorMessage = e.message ?? 'Unknown error';
        _state = VoiceInputState.error;
        _stopRecordingTimer();
        notifyListeners();
      case StreamingSttEvent.disconnected:
        if (_state == VoiceInputState.listening) {
          _state = VoiceInputState.error;
          _errorMessage = 'Connection lost';
          _stopRecordingTimer();
          notifyListeners();
        }
      default:
        break;
    }
  }

  @override
  void dispose() {
    _stopRecordingTimer();
    _hardPauseTimer?.cancel();
    _amplitudeTracker?.dispose();
    _transcriptSub?.cancel();
    _eventSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
