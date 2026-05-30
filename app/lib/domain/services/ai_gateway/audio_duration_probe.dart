import 'package:audioplayers/audioplayers.dart';
import '../../../utils/app_logger.dart';

/// Reads the duration of an audio file on disk, in milliseconds.
///
/// Used by the AI gateway to populate [UsageEvent.audioInputMs] for providers
/// that bill by audio duration (e.g. Sarvam STT — ₹30/hr). Decoupled from the
/// concrete metadata package so we can swap implementations without touching
/// the call sites.
///
/// **Current implementation:** uses [audioplayers] (already a project
/// dependency) to probe duration. We instantiate a player, set its source
/// to the file, read duration, then release. A short poll loop handles the
/// case where the native side hasn't published `duration` yet by the time
/// we ask. The package previously evaluated for this — `audio_info` — was
/// dropped because its v0.0.6 build artifacts targeted Java 21 and broke
/// the Android build (class file version mismatch with the AGP toolchain).
///
/// **Failure mode:** any error (corrupt file, missing codec, native crash)
/// returns `null` and logs a warning. The gateway records the usage event
/// regardless — cost ends up null, surfaced as "—" in the dashboard.
/// Telemetry must never block a user flow.
class AudioDurationProbe {
  AudioDurationProbe._();

  /// Up to ~1 second total wait for the native player to publish duration.
  /// In practice most local-file reads come back on the first or second
  /// poll; long files don't take measurably longer because the player isn't
  /// decoding the whole stream — it's just parsing the container header.
  static const _maxPollAttempts = 20;
  static const _pollInterval = Duration(milliseconds: 50);

  static Future<int?> probeMs(String filePath) async {
    final player = AudioPlayer();
    try {
      // Don't actually play — just set the source so the native side
      // populates duration from the file's container metadata.
      await player.setSourceDeviceFile(filePath);

      Duration? d = await player.getDuration();
      var attempts = 0;
      while (d == null && attempts < _maxPollAttempts) {
        await Future.delayed(_pollInterval);
        d = await player.getDuration();
        attempts++;
      }

      if (d == null || d.inMilliseconds <= 0) {
        AppLogger.warning(
          'AudioDurationProbe: no duration after $attempts polls for $filePath',
        );
        return null;
      }
      return d.inMilliseconds;
    } catch (e, st) {
      AppLogger.warning(
        'AudioDurationProbe: failed to read $filePath: $e\n$st',
      );
      return null;
    } finally {
      // Release native resources before disposing. Wrapped in try/catch so a
      // cleanup failure doesn't surface as a probe failure.
      try {
        await player.release();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
  }
}
