import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../backend/models/app_settings.dart';
import '../../domain/services/audio_backup_recorder.dart';
import '../../domain/services/streaming_amplitude_tracker.dart';
import '../../domain/services/streaming_recording_service.dart';
import '../../domain/services/stt_service.dart';
import '../../domain/services/transcript_formatter.dart';
import '../../utils/app_logger.dart';
import 'voice_input_controller.dart';

/// Batch (record-then-transcribe) voice input.
/// Records audio locally only; no network traffic while the user is speaking.
/// On stop(), runs a single transcription call against the file, then optional
/// formatting — both before transitioning to [VoiceInputState.done] so the
/// user gets a finished result from one tap.
class BatchVoiceInputController extends ChangeNotifier
    implements VoiceInputController {
  @override
  final bool isLive = false;

  final AppSettings settings;
  final bool enableFormatting;
  final String? formattingModelName;

  VoiceInputState _state = VoiceInputState.connecting;
  String _finalText = '';
  String? _formattedText;
  String? _errorMessage;
  bool _formattingFailed = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  StreamingRecordingService? _recorder;
  StreamingAmplitudeTracker? _amplitudeTracker;
  StreamSubscription<Uint8List>? _audioSub;

  final AudioBackupRecorder _backup = AudioBackupRecorder();

  BatchVoiceInputController({
    required this.settings,
    this.enableFormatting = false,
    this.formattingModelName,
  });

  @override
  VoiceInputState get state => _state;
  @override
  String get finalText => _finalText;
  @override
  String? get formattedText => _formattedText;
  @override
  bool get formattingFailed => _formattingFailed;

  /// In batch mode no partial transcripts arrive — display the final
  /// transcription only after stop() resolves it. While recording this
  /// returns empty and the widget shows an instruction hint instead.
  @override
  String get displayText => _finalText;

  @override
  String? get errorMessage => _errorMessage;
  @override
  int get recordingSeconds => _recordingSeconds;
  @override
  List<double> get amplitudeLevels =>
      _amplitudeTracker?.levels ?? List.filled(15, 0.0);

  @override
  String? get backupPcmPath => _backup.pcmPath;
  @override
  String? get backupWavPath => _backup.wavPath;

  @override
  Future<void> start() async {
    _state = VoiceInputState.connecting;
    notifyListeners();

    try {
      await _backup.start();
    } catch (e) {
      // The backup file IS our transcription source in batch mode — if we
      // can't write it, the session has no point. Bail out with error.
      AppLogger.error('BatchVoiceInputController: backup start failed', e);
      _setErrorState('Could not start recording: $e');
      return;
    }

    _recorder = StreamingRecordingService();

    try {
      final stream = await _recorder!.startStream();
      _audioSub = stream.listen(_backup.write);

      _amplitudeTracker = StreamingAmplitudeTracker(
        recorder: _recorder!,
        onUpdate: notifyListeners,
      );
      _amplitudeTracker!.start();

      _state = VoiceInputState.listening;
      _startRecordingTimer();
      notifyListeners();
    } catch (e) {
      AppLogger.error('BatchVoiceInputController: failed to start', e);
      _setErrorState(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Future<void> pause() async {
    if (_state != VoiceInputState.listening) return;

    _stopRecordingTimer();
    _amplitudeTracker?.stop();
    await _recorder?.pause();

    _state = VoiceInputState.paused;
    notifyListeners();
  }

  @override
  Future<void> resume() async {
    if (_state != VoiceInputState.paused) return;

    await _recorder?.resume();
    _amplitudeTracker?.start();

    _state = VoiceInputState.listening;
    _startRecordingTimer();
    notifyListeners();
  }

  @override
  Future<String?> stop() async {
    _stopRecordingTimer();
    _amplitudeTracker?.stop();

    _state = VoiceInputState.processing;
    notifyListeners();

    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.stop();

    final wavPath = await _backup.finalize();
    if (wavPath == null) {
      AppLogger.error('BatchVoiceInputController: no audio captured');
      _setErrorState('No audio was recorded.');
      return null;
    }
    AppLogger.info('BatchVoiceInputController: transcribing $wavPath');

    try {
      final transcript = await SttService.transcribe(
        wavPath,
        settings: settings,
      );
      _finalText = (transcript ?? '').trim();
    } catch (e) {
      AppLogger.error('BatchVoiceInputController: transcription failed', e);
      _setErrorState(e.toString().replaceFirst('Exception: ', ''));
      return null;
    }

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

    final result = await TranscriptFormatter.format(
      _finalText,
      modelName: formattingModelName,
    );
    _formattedText = result.text;
    _formattingFailed = result.failed;

    _state = VoiceInputState.done;
    notifyListeners();

    return _formattedText ?? _finalText;
  }

  @override
  Future<String?> retryFormatting() async {
    if (_finalText.isEmpty) return null;

    _state = VoiceInputState.formatting;
    _formattingFailed = false;
    notifyListeners();

    final result = await TranscriptFormatter.format(
      _finalText,
      modelName: formattingModelName,
    );
    _formattedText = result.text;
    _formattingFailed = result.failed;

    _state = VoiceInputState.done;
    notifyListeners();

    return _formattedText ?? _finalText;
  }

  @override
  Future<void> cancel() async {
    _stopRecordingTimer();
    _amplitudeTracker?.stop();
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.stop();
    // Keep the .pcm — user may still want to recover it via cleanup tooling.
    await _backup.abort();
  }

  @override
  Future<void> retry() async {
    _finalText = '';
    _formattedText = null;
    _formattingFailed = false;
    _errorMessage = null;
    _recordingSeconds = 0;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.dispose();
    _recorder = null;
    await _backup.abort();
    await start();
  }

  void _setErrorState(String message) {
    _errorMessage = message;
    _state = VoiceInputState.error;
    _stopRecordingTimer();
    notifyListeners();
    // Make sure a .wav is on disk so the user can recover their audio even
    // after a transcription error.
    _backup.finalize();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingSeconds++;
      notifyListeners();
      if (_recordingSeconds >= VoiceInputController.maxRecordingSeconds) {
        stop();
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  @override
  void dispose() {
    _stopRecordingTimer();
    _amplitudeTracker?.dispose();
    _audioSub?.cancel();
    _recorder?.dispose();
    _backup.finalize();
    super.dispose();
  }
}
