import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/app_logger.dart';
import 'media_resolver.dart' show MediaDownloader;

/// Low-level, crash-safe writer for downloaded media files.
///
/// Two guarantees that the whole background-hydration design rests on:
///
///  1. **Atomic writes.** Bytes are written to a `<name>.part` scratch file and
///     only `rename`d onto the final path once complete. A process kill / power
///     loss mid-download therefore leaves a `.part` file (or nothing) — NEVER a
///     half-written file at the real path that a later run would mistake for a
///     good image. A file at the final path is always whole.
///  2. **Single in-flight download per target.** Concurrent callers (e.g. the
///     background sweep and an on-view lazy resolve hitting the same image)
///     share one download instead of racing to write the same file.
///
/// The ONLY thing this ever deletes is its own `.part` scratch file. It never
/// touches a completed media file.
class MediaCache {
  MediaCache._();

  /// Suffix for in-progress scratch files. Public so the hydration sweep can
  /// recognise (and clean up) stray scratch from a previous interrupted run.
  static const String scratchSuffix = '.part';

  static final Map<String, Future<File?>> _inFlight = {};

  /// Downloads [fileName] into [dir] via [downloader], atomically. Returns the
  /// finished file, or null if the download failed (offline / not on Drive /
  /// error) — in which case no partial file is left behind. Safe to call
  /// concurrently for the same target; callers share one download.
  static Future<File?> fetch(
    String fileName,
    Directory dir,
    MediaDownloader downloader,
  ) {
    final finalPath = p.join(dir.path, fileName);
    final existing = _inFlight[finalPath];
    if (existing != null) return existing;

    // NOTE: the callback must return void — returning _inFlight.remove(...)
    // would hand whenComplete the very future we're building, which it would
    // then await, deadlocking. The braces keep it a statement.
    final future = _download(fileName, finalPath, downloader)
        .whenComplete(() {
      _inFlight.remove(finalPath);
    });
    _inFlight[finalPath] = future;
    return future;
  }

  static Future<File?> _download(
    String fileName,
    String finalPath,
    MediaDownloader downloader,
  ) async {
    final scratch = File('$finalPath$scratchSuffix');
    try {
      final ok = await downloader(fileName, scratch);
      if (!ok || !await scratch.exists()) {
        await _deleteScratch(scratch);
        return null;
      }
      // Atomic publish: a reader of finalPath sees all-or-nothing.
      return await scratch.rename(finalPath);
    } catch (e) {
      AppLogger.warning('[MediaCache] fetch "$fileName" failed: $e');
      await _deleteScratch(scratch);
      return null;
    }
  }

  /// Removes leftover `.part` scratch files in [dir] from a previous run that
  /// was interrupted mid-download. These are this class's own temporaries — the
  /// only files it is ever permitted to delete. Best-effort; never throws.
  static Future<void> cleanScratch(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith(scratchSuffix)) {
          await _deleteScratch(entity);
        }
      }
    } catch (e) {
      AppLogger.warning('[MediaCache] cleanScratch failed in ${dir.path}: $e');
    }
  }

  static Future<void> _deleteScratch(File scratch) async {
    try {
      if (await scratch.exists()) await scratch.delete();
    } catch (_) {
      // A scratch file we couldn't remove is harmless — it'll be retried next
      // cleanScratch. Never let it surface as an error.
    }
  }
}
