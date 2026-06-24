import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/services/audio_backup_recorder.dart';
import '../../domain/services/streaming_amplitude_tracker.dart';
import '../../domain/services/streaming_stt_provider.dart';
import '../../domain/services/streaming_transcription_service.dart';
import '../../domain/services/transcript_formatter.dart';
import '../../utils/app_logger.dart';
import '../../utils/dispose_safe_notifier.dart';
import 'voice_input_controller.dart';

/// Live-streaming voice input.
/// Audio chunks go to Sarvam over a WebSocket; partial transcripts arrive
/// while the user is still speaking. Pause has both soft (mic only) and hard
/// (mic + WS close) modes so a tailor's 30-second silence between measurements
/// doesn't keep an idle server connection open and billing.
class LiveVoiceInputController extends ChangeNotifier
    with DisposeSafeNotifier
    implements VoiceInputController {
  static const _hardPauseDelaySeconds = 10;

  @override
  final bool isLive = true;

  final bool enableFormatting;
  final String? formattingModelName;
  final String? formattingPromptOverride;

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
  bool _isReconnecting = false;

  StreamingTranscriptionService _service = StreamingTranscriptionService();
  StreamingAmplitudeTracker? _amplitudeTracker;
  StreamSubscription<StreamingTranscript>? _transcriptSub;
  StreamSubscription<StreamingSttEventData>? _eventSub;

  /// One backup recording per controller session. Owned at the controller
  /// level so service swaps (hard-resume, auto-reconnect) all write into the
  /// SAME file — the user gets one continuous audio file per measurement.
  final AudioBackupRecorder _backup = AudioBackupRecorder();

  LiveVoiceInputController({
    this.enableFormatting = false,
    this.formattingModelName,
    this.formattingPromptOverride,
  });

  @override
  VoiceInputState get state => _state;
  @override
  String get finalText => _finalText;
  String get partialText => _partialText;
  @override
  String? get formattedText => _formattedText;
  @override
  bool get formattingFailed => _formattingFailed;
  @override
  String get displayText {
    if (_finalText.isEmpty && _partialText.isEmpty) return '';
    if (_partialText.isEmpty) return _finalText;
    if (_finalText.isEmpty) return _partialText;
    return '$_finalText $_partialText';
  }
  @override
  String? get errorMessage => _errorMessage;
  @override
  int get recordingSeconds => _recordingSeconds;
  @override
  List<double> get amplitudeLevels => _amplitudeTracker?.levels ?? List.filled(15, 0.0);

  @override
  String? get backupPcmPath => _backup.pcmPath;
  @override
  String? get backupWavPath => _backup.wavPath;

  @override
  Future<void> start() async {
    _state = VoiceInputState.connecting;
    safeNotify();

    try {
      await _backup.start();
    } catch (e) {
      AppLogger.error('LiveVoiceInputController: backup start failed', e);
    }

    try {
      _service.onAudioChunk = _backup.write;
      _transcriptSub = _service.transcripts.listen(_onTranscript);
      _eventSub = _service.events.listen(_onEvent);

      await _service.start();
      if (isDisposed) return;

      if (_service.recorder != null) {
        _amplitudeTracker = StreamingAmplitudeTracker(
          recorder: _service.recorder!,
          onUpdate: safeNotify,
        );
        _amplitudeTracker!.start();
      }

      _state = VoiceInputState.listening;
      _startRecordingTimer();
      safeNotify();
    } catch (e) {
      AppLogger.error('LiveVoiceInputController: failed to start', e);
      _setErrorState(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Future<void> pause() async {
    if (_state != VoiceInputState.listening) return;

    _stopRecordingTimer();
    _amplitudeTracker?.stop();
    _state = VoiceInputState.paused;
    _hardPaused = false;
    safeNotify();

    await _service.pauseAudio();
    _service.sendFlush();

    _hardPauseTimer?.cancel();
    _hardPauseTimer = Timer(
      const Duration(seconds: _hardPauseDelaySeconds),
      _performHardPause,
    );
  }

  Future<void> _performHardPause() async {
    if (_state != VoiceInputState.paused || _hardPaused) return;

    AppLogger.info('LiveVoiceInputController: hard pause — closing stream');
    _hardPaused = true;

    _amplitudeTracker?.dispose();
    _amplitudeTracker = null;

    // Flush + close the WS for side effects only. Do NOT overwrite _finalText
    // with service.stop()'s return — that returns only THIS service's
    // accumulator, which after a previous hard-resume contains only the
    // latest segment. _onTranscript has already been maintaining _finalText
    // incrementally over the controller's full lifetime.
    await _service.stop();
    _partialText = '';

    await _transcriptSub?.cancel();
    _transcriptSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _service.dispose();
  }

  @override
  Future<void> resume() async {
    if (_state != VoiceInputState.paused) return;

    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;

    if (!_hardPaused) {
      await _service.resumeAudio();
      _amplitudeTracker?.start();
      _state = VoiceInputState.listening;
      _startRecordingTimer();
      safeNotify();
      return;
    }

    _state = VoiceInputState.connecting;
    safeNotify();

    final savedText = _finalText;
    _service = StreamingTranscriptionService();

    try {
      _service.onAudioChunk = _backup.write;
      _transcriptSub = _service.transcripts.listen(_onTranscript);
      _eventSub = _service.events.listen(_onEvent);

      await _service.start();
      if (isDisposed) return;

      if (_service.recorder != null) {
        _amplitudeTracker = StreamingAmplitudeTracker(
          recorder: _service.recorder!,
          onUpdate: safeNotify,
        );
        _amplitudeTracker!.start();
      }

      _finalText = savedText;
      _state = VoiceInputState.listening;
      _startRecordingTimer();
      safeNotify();
    } catch (e) {
      AppLogger.error('LiveVoiceInputController: failed to resume', e);
      _finalText = savedText;
      _setErrorState(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Transparently rebuild the service after the WS drops mid-listening.
  /// Preserves [_finalText] across the swap.
  Future<void> _reconnectAfterDrop() async {
    if (_isReconnecting) return;
    _isReconnecting = true;

    final savedText = _finalText;

    _stopRecordingTimer();
    _amplitudeTracker?.dispose();
    _amplitudeTracker = null;

    await _transcriptSub?.cancel();
    _transcriptSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    try {
      await _service.dispose();
    } catch (_) {}

    _service = StreamingTranscriptionService();

    try {
      _service.onAudioChunk = _backup.write;
      _transcriptSub = _service.transcripts.listen(_onTranscript);
      _eventSub = _service.events.listen(_onEvent);
      await _service.start();
      if (isDisposed) return;

      if (_service.recorder != null) {
        _amplitudeTracker = StreamingAmplitudeTracker(
          recorder: _service.recorder!,
          onUpdate: safeNotify,
        );
        _amplitudeTracker!.start();
      }

      _finalText = savedText;
      _state = VoiceInputState.listening;
      _startRecordingTimer();
      safeNotify();
      AppLogger.info('LiveVoiceInputController: auto-reconnect succeeded');
    } catch (e) {
      AppLogger.error('LiveVoiceInputController: auto-reconnect failed', e);
      _finalText = savedText;
      _setErrorState('Connection lost');
    } finally {
      _isReconnecting = false;
    }
  }

  @override
  Future<String?> stop() async {
    _stopRecordingTimer();
    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;
    _amplitudeTracker?.stop();

    if (_state == VoiceInputState.paused && _hardPaused) {
      return _finalize();
    }

    _state = VoiceInputState.processing;
    safeNotify();

    await _service.stop();
    _partialText = '';

    return _finalize();
  }

  Future<String?> _finalize() async {
    final wavPath = await _backup.finalize();
    if (wavPath != null) {
      AppLogger.info('LiveVoiceInputController: backup audio available at $wavPath');
    }

    if (_finalText.isEmpty) {
      _state = VoiceInputState.done;
      safeNotify();
      return null;
    }

    if (!enableFormatting) {
      _state = VoiceInputState.done;
      safeNotify();
      return _finalText;
    }

    _state = VoiceInputState.formatting;
    _formattingFailed = false;
    safeNotify();

    final result = await TranscriptFormatter.format(
      _finalText,
      modelName: formattingModelName,
      formattingPromptOverride: formattingPromptOverride,
    );
    _formattedText = result.text;
    _formattingFailed = result.failed;

    _state = VoiceInputState.done;
    safeNotify();

    return _formattedText ?? _finalText;
  }

  @override
  Future<String?> retryFormatting() async {
    if (_finalText.isEmpty) return null;

    _state = VoiceInputState.formatting;
    _formattingFailed = false;
    safeNotify();

    final result = await TranscriptFormatter.format(
      _finalText,
      modelName: formattingModelName,
      formattingPromptOverride: formattingPromptOverride,
    );
    _formattedText = result.text;
    _formattingFailed = result.failed;

    _state = VoiceInputState.done;
    safeNotify();

    return _formattedText ?? _finalText;
  }

  @override
  Future<void> cancel() async {
    _stopRecordingTimer();
    _hardPauseTimer?.cancel();
    _hardPauseTimer = null;
    _amplitudeTracker?.stop();
    await _backup.abort();
    if (_state == VoiceInputState.paused && _hardPaused) {
      return;
    }
    await _service.cancel();
  }

  @override
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
    await _backup.abort();
    await _service.cancel();
    _service = StreamingTranscriptionService();
    await start();
  }

  void _setErrorState(String message) {
    _errorMessage = message;
    _state = VoiceInputState.error;
    _stopRecordingTimer();
    safeNotify();
    _backup.finalize();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingSeconds++;
      safeNotify();
      if (_recordingSeconds >= VoiceInputController.maxRecordingSeconds) {
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
    safeNotify();
  }

  void _onEvent(StreamingSttEventData e) {
    switch (e.event) {
      case StreamingSttEvent.error:
        AppLogger.error('LiveVoiceInputController: stt error event: ${e.message}');
        _setErrorState(e.message ?? 'Unknown error');
      case StreamingSttEvent.disconnected:
        AppLogger.warning(
          'LiveVoiceInputController: disconnected while state=$_state, hardPaused=$_hardPaused',
        );
        if (_state == VoiceInputState.listening && !_isReconnecting) {
          AppLogger.warning('LiveVoiceInputController: WS dropped mid-listening — auto-reconnecting');
          _reconnectAfterDrop();
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
    _backup.finalize();
    _service.dispose();
    super.dispose();
  }
}
