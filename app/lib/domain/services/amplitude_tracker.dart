import 'dart:async';
import 'dart:ui' show VoidCallback;
import 'audio_recording_service.dart';

/// Tracks microphone amplitude and maintains a waveform level history.
class AmplitudeTracker {
  // --- Config ---
  final int barCount;
  final int pollMs;
  final int msPerBar;

  late final int _samplesPerBar;
  Timer? _timer;
  final List<double> _sampleBuffer = [];
  late final List<double> levels;

  /// Callback when levels update.
  final VoidCallback? onUpdate;

  AmplitudeTracker({
    this.barCount = 15,
    this.pollMs = 100,
    this.msPerBar = 100,
    this.onUpdate,
  }) : _samplesPerBar = msPerBar ~/ pollMs {
    levels = List.generate(barCount, (_) => 0.0);
  }

  void start() {
    _timer?.cancel();
    _sampleBuffer.clear();
    _timer = Timer.periodic(Duration(milliseconds: pollMs), (_) async {
      try {
        final amp = await AudioRecordingService.getAmplitude();
        // dBFS range: -160 (silence) to 0 (max).
        // Practical speech range is roughly -50 to -5 dBFS.
        final normalized = ((amp.current + 50) / 45).clamp(0.0, 1.0);
        _sampleBuffer.add(normalized);

        if (_sampleBuffer.length >= _samplesPerBar) {
          final avg = _sampleBuffer.reduce((a, b) => a + b) / _sampleBuffer.length;
          _sampleBuffer.clear();
          levels.removeAt(0);
          levels.add(avg);
        }
        onUpdate?.call();
      } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _sampleBuffer.clear();
  }

  void dispose() {
    stop();
  }
}
