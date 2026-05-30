import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../utils/app_logger.dart';

/// Fail-safe local recording of every PCM byte streamed to the STT service.
///
/// The goal: even if Sarvam errors out, the network drops, the WS reconnects,
/// the app crashes, or anything else goes wrong with transcription — the raw
/// audio is still on disk and the user can recover their dictation.
///
/// Strategy:
///  - Writes incrementally to a `.pcm` file (no header). Every byte that
///    arrives is flushed to disk synchronously via [IOSink.add]. Raw PCM has
///    no length field anywhere, so a crash mid-recording leaves a file that
///    is fully recoverable (just shorter than expected).
///  - On [finalize], writes a sibling `.wav` file with a proper RIFF header
///    so the user can play it back with any audio player. The `.pcm` is kept
///    as the authoritative source — finalize is purely additive.
///  - On [abort], the file is left intact (NOT deleted). Recovery first,
///    cleanup later.
class AudioBackupRecorder {
  static const _subdir = 'audio_backups';

  final int sampleRate;
  final int channels;
  final int bitsPerSample;

  IOSink? _sink;
  String? _pcmPath;
  String? _wavPath;
  int _byteCount = 0;

  AudioBackupRecorder({
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
  });

  bool get isRecording => _sink != null;
  String? get pcmPath => _pcmPath;
  String? get wavPath => _wavPath;
  int get byteCount => _byteCount;

  /// Seconds of audio captured so far (based on byte count + format).
  double get durationSeconds {
    final bytesPerSecond = sampleRate * channels * (bitsPerSample ~/ 8);
    if (bytesPerSecond == 0) return 0;
    return _byteCount / bytesPerSecond;
  }

  /// Returns the directory backups are stored in. Creates it if missing.
  static Future<Directory> backupsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Lists all backup files (both .pcm and .wav) sorted newest-first.
  static Future<List<File>> listBackups() async {
    final dir = await backupsDirectory();
    final entries = await dir.list().toList();
    final files = entries.whereType<File>().toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Begin recording. Returns the .pcm file path being written to.
  /// If a recording is already active, this throws — controller must
  /// finalize/abort first.
  Future<String> start({String? sessionId}) async {
    if (_sink != null) {
      throw StateError('AudioBackupRecorder already recording to $_pcmPath');
    }

    final dir = await backupsDirectory();
    final stamp = (sessionId ?? DateTime.now().toIso8601String())
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    _pcmPath = '${dir.path}/$stamp.pcm';
    _wavPath = '${dir.path}/$stamp.wav';
    _byteCount = 0;
    _sink = File(_pcmPath!).openWrite();
    AppLogger.info('AudioBackupRecorder: started -> $_pcmPath');
    return _pcmPath!;
  }

  /// Append a chunk of raw PCM bytes. Safe to call after dispose / before
  /// start — it just no-ops, so a stray late chunk from a torn-down service
  /// can't crash the app.
  void write(Uint8List chunk) {
    final sink = _sink;
    if (sink == null) return;
    try {
      sink.add(chunk);
      _byteCount += chunk.length;
    } catch (e) {
      // Disk full, file deleted underneath us, permission revoked, etc.
      // Log and stop recording — but DO NOT crash the transcription path.
      AppLogger.error('AudioBackupRecorder: write failed', e);
      _sink = null;
    }
  }

  /// Flush, close the PCM sink, and emit a sibling .wav file for playback.
  /// Returns the path of the .wav (or null if nothing was written).
  Future<String?> finalize() async {
    final sink = _sink;
    final pcm = _pcmPath;
    final wav = _wavPath;
    _sink = null;
    if (sink == null || pcm == null || wav == null) return null;

    try {
      await sink.flush();
      await sink.close();
    } catch (e) {
      AppLogger.error('AudioBackupRecorder: close failed', e);
    }

    if (_byteCount == 0) {
      // Nothing was captured. Delete the empty .pcm so we don't leave junk.
      try {
        await File(pcm).delete();
      } catch (_) {}
      AppLogger.info('AudioBackupRecorder: finalized with 0 bytes — deleted empty file');
      return null;
    }

    try {
      await _writeWavFromPcm(pcm, wav);
      AppLogger.info(
        'AudioBackupRecorder: finalized -> $wav '
        '(${durationSeconds.toStringAsFixed(1)}s, $_byteCount bytes)',
      );
      // .wav is now the source of truth — drop the .pcm to avoid doubling
      // disk usage on every successful session. If wav generation FAILED
      // we hit the catch block below and keep .pcm intact for recovery.
      try {
        await File(pcm).delete();
      } catch (e) {
        AppLogger.warning('AudioBackupRecorder: could not delete pcm after wav write: $e');
      }
      return wav;
    } catch (e) {
      AppLogger.error('AudioBackupRecorder: wav generation failed (pcm still safe at $pcm)', e);
      return null;
    }
  }

  /// Stop without producing a .wav. The .pcm is left on disk for recovery.
  Future<void> abort() async {
    final sink = _sink;
    _sink = null;
    if (sink == null) return;
    try {
      await sink.flush();
      await sink.close();
    } catch (_) {}
    AppLogger.info('AudioBackupRecorder: aborted — pcm preserved at $_pcmPath');
  }

  Future<void> _writeWavFromPcm(String pcmPath, String wavPath) async {
    final pcmBytes = await File(pcmPath).readAsBytes();
    final header = _buildWavHeader(pcmBytes.length);
    final out = File(wavPath).openWrite();
    out.add(header);
    out.add(pcmBytes);
    await out.flush();
    await out.close();
  }

  Uint8List _buildWavHeader(int dataSize) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    header.setUint32(4, fileSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // fmt subchunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }
}
