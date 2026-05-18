import 'dart:async';
import 'dart:ui';
import 'streaming_recording_service.dart';

class StreamingAmplitudeTracker {
  final StreamingRecordingService recorder;
  final int barCount;
  final int pollMs;
  final VoidCallback? onUpdate;

  Timer? _timer;
  final List<double> levels;

  StreamingAmplitudeTracker({
    required this.recorder,
    this.barCount = 15,
    this.pollMs = 100,
    this.onUpdate,
  }) : levels = List.generate(barCount, (_) => 0.0);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: pollMs), (_) async {
      if (!recorder.isRecording) return;
      try {
        final amp = await recorder.getAmplitude();
        final normalized = ((amp.current + 50) / 45).clamp(0.0, 1.0);
        levels.removeAt(0);
        levels.add(normalized);
        onUpdate?.call();
      } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
