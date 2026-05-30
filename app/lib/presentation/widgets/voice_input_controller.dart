import 'package:flutter/foundation.dart';

import '../../backend/models/app_settings.dart';
import 'batch_voice_input_controller.dart';
import 'live_voice_input_controller.dart';

/// Lifecycle states shared by every voice-input controller.
/// Two of these are streaming-only in spirit ([connecting] is meaningful for
/// live STT; batch controllers may still surface it briefly when warming up
/// the mic), but keeping a single enum lets the UI handle both paths uniformly.
enum VoiceInputState { connecting, listening, paused, processing, formatting, done, error }

/// Common surface area for any "record some audio and produce a transcript"
/// flow. Two implementations exist today:
///  - [LiveVoiceInputController]   — streams audio to Sarvam over a WebSocket
///                                   and accumulates partial transcripts live.
///  - [BatchVoiceInputController]  — records locally, then on stop() runs a
///                                   single transcription call (e.g. Gemini).
///
/// The widget treats both identically. Pick one via [VoiceInputController.create].
abstract class VoiceInputController extends ChangeNotifier {
  /// Hard ceiling on a single session — same in both modes.
  static const int maxRecordingSeconds = 300;

  VoiceInputState get state;
  String get displayText;
  String get finalText;
  String? get formattedText;
  bool get formattingFailed;
  String? get errorMessage;
  int get recordingSeconds;
  List<double> get amplitudeLevels;

  /// Path to the recorded audio. In batch mode this IS the source of truth
  /// fed to the transcriber. In streaming mode it's a fail-safe backup. In
  /// both cases it's a 16 kHz mono PCM WAV.
  String? get backupWavPath;
  String? get backupPcmPath;

  /// True when this controller streams partial transcripts live to the UI
  /// during recording. The UI hides the transcript pane and updates status
  /// copy when this is false.
  bool get isLive;

  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<String?> stop();
  Future<void> cancel();
  Future<String?> retryFormatting();
  Future<void> retry();

  /// Build the right controller for the user's chosen STT model.
  /// Convention: [AppSettings.sttModel] is a `<provider>:<model>` string —
  /// `sarvam:*` → live streaming, `gemini:*` → batch.
  factory VoiceInputController.create({
    required AppSettings settings,
    bool enableFormatting = false,
    String? formattingModelName,
  }) {
    final prefix = settings.sttModel.split(':').first;
    if (prefix == 'gemini') {
      return BatchVoiceInputController(
        settings: settings,
        enableFormatting: enableFormatting,
        formattingModelName: formattingModelName,
      );
    }
    return LiveVoiceInputController(
      enableFormatting: enableFormatting,
      formattingModelName: formattingModelName,
    );
  }
}
