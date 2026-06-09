import 'dart:io';

import '../../../utils/app_logger.dart';
import '../audio_backup_recorder.dart';
import 'recording_metadata.dart';

/// Reads/writes the per-recording sidecar JSON and lists recordings for the
/// Recordings debugger. The audio itself stays where [AudioBackupRecorder]
/// already writes it (`…/audio_backups/<stem>.wav`); a sidecar lives next to
/// it as `<stem>.json`.
class RecordingStore {
  RecordingStore._();

  // The recorder captures 16 kHz mono 16-bit PCM → 32000 bytes/sec; the WAV
  // wrapper adds a 44-byte header. Used to estimate duration from file size
  // without decoding the file.
  static const int _bytesPerSecond = 16000 * 1 * 2;
  static const int _wavHeaderBytes = 44;

  static String _stemOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? path : path.substring(0, dot);
  }

  static String _sidecarPathFor(String wavPath) => '${_stemOf(wavPath)}.json';

  /// Best-effort: write the sidecar JSON next to [wavPath]. Never throws —
  /// failing to record debug metadata must not break a save / commit / turn.
  static Future<void> writeSidecar(
    String? wavPath,
    RecordingMetadata meta,
  ) async {
    if (wavPath == null || wavPath.trim().isEmpty) return;
    try {
      await File(_sidecarPathFor(wavPath)).writeAsString(meta.encode());
    } catch (e) {
      AppLogger.warning('RecordingStore: write sidecar failed for $wavPath: $e');
    }
  }

  /// All playable recordings, newest first, each paired with its sidecar.
  static Future<List<RecordingEntry>> listAll() async {
    final files = await AudioBackupRecorder.listBackups();
    final entries = <RecordingEntry>[];
    for (final wav in files) {
      if (!wav.path.toLowerCase().endsWith('.wav')) continue;
      try {
        final stat = await wav.stat();
        final durSecs = (stat.size - _wavHeaderBytes) / _bytesPerSecond;
        final meta = await _readSidecar(wav.path);
        entries.add(RecordingEntry(
          wav: wav,
          createdAt: meta?.createdAt ?? stat.modified,
          sizeBytes: stat.size,
          duration: Duration(
            milliseconds: (durSecs * 1000).clamp(0, 1 << 31).round(),
          ),
          meta: meta,
        ));
      } catch (e) {
        AppLogger.warning('RecordingStore: skip ${wav.path}: $e');
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  static Future<RecordingMetadata?> _readSidecar(String wavPath) async {
    try {
      final file = File(_sidecarPathFor(wavPath));
      if (!await file.exists()) return null;
      return RecordingMetadata.decode(await file.readAsString());
    } catch (_) {
      return null; // A corrupt sidecar shouldn't hide the recording.
    }
  }

  /// Whether a recording has a sidecar — used by the cleanup sweep to retain
  /// debugging recordings instead of deleting them as orphans.
  static Future<bool> hasSidecar(String wavPath) =>
      File(_sidecarPathFor(wavPath)).exists();

  /// Delete a recording and everything tied to it (wav + sidecar + any
  /// leftover .pcm).
  static Future<void> delete(RecordingEntry entry) =>
      deleteByWavPath(entry.wav.path);

  static Future<void> deleteByWavPath(String wavPath) async {
    final stem = _stemOf(wavPath);
    for (final ext in const ['.wav', '.json', '.pcm']) {
      try {
        final f = File('$stem$ext');
        if (await f.exists()) await f.delete();
      } catch (e) {
        AppLogger.warning('RecordingStore: delete $stem$ext failed: $e');
      }
    }
  }

  /// Delete recordings older than [age]. Returns the number of WAVs removed.
  static Future<int> deleteOlderThan(Duration age) async {
    final entries = await listAll();
    final cutoff = DateTime.now().subtract(age);
    var removed = 0;
    for (final e in entries) {
      if (e.createdAt.isBefore(cutoff)) {
        await deleteByWavPath(e.wav.path);
        removed++;
      }
    }
    return removed;
  }
}
