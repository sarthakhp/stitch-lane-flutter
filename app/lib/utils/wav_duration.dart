import 'dart:io';

/// Cheap duration estimate for the app's own recordings, computed from file
/// SIZE — no decoding, no loading the audio into a player.
///
/// The recorder ([AudioBackupRecorder]) always writes 16 kHz mono 16-bit PCM
/// WAV, so bytes map directly to time: `seconds = (size - 44) / 32000`. Used
/// to show a recording's length up front without opening it.
class WavDuration {
  WavDuration._();

  // 16000 Hz * 1 channel * 2 bytes/sample.
  static const int bytesPerSecond = 16000 * 1 * 2;
  static const int headerBytes = 44;

  /// Estimate from a file size in bytes. Returns null if not a positive size.
  static Duration? fromBytes(int sizeBytes) {
    if (sizeBytes <= headerBytes) return Duration.zero;
    final seconds = (sizeBytes - headerBytes) / bytesPerSecond;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Estimate from a `.wav` file via a metadata stat (no byte read). Returns
  /// null for non-wav or unreadable files — callers fall back to the real
  /// duration the player reports once playback starts.
  static Duration? fromFile(File file) {
    if (!file.path.toLowerCase().endsWith('.wav')) return null;
    try {
      return fromBytes(file.lengthSync());
    } catch (_) {
      return null;
    }
  }
}
