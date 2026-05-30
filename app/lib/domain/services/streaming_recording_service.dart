import 'dart:typed_data';
import 'package:record/record.dart';
import '../../utils/app_logger.dart';

class StreamingRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;

  Future<Stream<Uint8List>> startStream() async {
    if (_isRecording) {
      throw StateError('Already recording');
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    AppLogger.info('StreamingRecorder: starting PCM stream at 16kHz (VOICE_RECOGNITION source)');

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        // VOICE_RECOGNITION routes through the device's audio HAL, which on
        // most modern Androids enables multi-mic beamforming + NS + AGC tuned
        // for speech. Big WER win vs the default MIC source on far-field /
        // phone-on-table scenarios.
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
      ),
    );

    _isRecording = true;
    return stream;
  }

  Future<Amplitude> getAmplitude() async {
    return _recorder.getAmplitude();
  }

  Future<void> pause() async {
    if (!_isRecording || _isPaused) return;
    AppLogger.info('StreamingRecorder: pausing');
    await _recorder.pause();
    _isPaused = true;
  }

  Future<void> resume() async {
    if (!_isRecording || !_isPaused) return;
    AppLogger.info('StreamingRecorder: resuming');
    await _recorder.resume();
    _isPaused = false;
  }

  Future<void> stop() async {
    if (!_isRecording) return;

    AppLogger.info('StreamingRecorder: stopping');
    await _recorder.stop();
    _isRecording = false;
  }

  Future<void> dispose() async {
    await stop();
    _recorder.dispose();
  }
}
