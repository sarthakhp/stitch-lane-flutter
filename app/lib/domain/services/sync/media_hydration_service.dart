import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/app_logger.dart';
import '../drive_service.dart';
import 'media_cache.dart';
import 'media_resolver.dart';
import 'restore_media_state.dart';

/// Pulls Drive media (images + audio) onto this device in the background after
/// a restore, so the user can start using the app immediately instead of
/// waiting for every photo to download up front.
///
/// It is deliberately **stateless and resumable**: each run recomputes the work
/// from durable facts — "what's on Drive" minus "what's already on disk" — and
/// downloads only the gaps. There is no checkpoint to corrupt, so a kill at any
/// moment (app closed in 5s, battery dies, OS kill) is harmless: the next launch
/// recomputes a slightly larger gap and continues. Writes are atomic (via
/// [MediaCache]) and it is **download-only — it never deletes a media file**,
/// only its own leftover `.part` scratch from an interrupted run.
///
/// Anything the user opens before the sweep reaches it is covered by the on-view
/// lazy path in [MediaResolver], which shares a single download via [MediaCache].
class MediaHydrationService {
  MediaHydrationService._();

  // One sweep per process. A second caller (e.g. startup + restore both firing)
  // just no-ops rather than running a duplicate pass.
  static bool _running = false;

  // Set by [cancel] (e.g. on sign-out) to stop an in-flight sweep promptly so
  // it can't keep repopulating files that are being wiped, or fetch a
  // signed-out account's media. Reset at the start of each fresh run.
  static bool _cancelled = false;

  /// Stops an in-flight sweep at the next file boundary. Safe to call any time;
  /// a later [hydrate] clears the cancellation for a new run.
  static void cancel() => _cancelled = true;

  /// Fire-and-forget entry point. Safe to call on every launch and after every
  /// restore; cheap when nothing is pending. Never throws.
  static Future<void> hydrate() async {
    if (_running) return;
    _running = true;
    _cancelled = false;
    try {
      final imagesComplete = await _sweep(
        dirProvider: MediaResolver.imagesDir,
        list: (api) => DriveServiceImageOperations.listImagesInFolder(api),
        download: (api, id) =>
            DriveServiceImageOperations.downloadImage(api, id),
        label: 'images',
      );
      final audiosComplete = await _sweep(
        dirProvider: MediaResolver.audioDir,
        list: (api) => DriveServiceAudioOperations.listAudiosInFolder(api),
        download: (api, id) =>
            DriveServiceAudioOperations.downloadAudio(api, id),
        label: 'audio',
      );

      // Only declare hydration done when BOTH media types were fully reconciled
      // (Drive reachable and every file now local). Otherwise leave the flag set
      // so the next launch resumes.
      if (imagesComplete && audiosComplete) {
        await RestoreMediaState.clearPending();
        AppLogger.info('[MediaHydration] complete — all media present locally');
      } else {
        AppLogger.info(
          '[MediaHydration] incomplete (offline or failures) — will resume',
        );
      }
    } catch (e) {
      AppLogger.warning('[MediaHydration] sweep aborted: $e');
    } finally {
      _running = false;
    }
  }

  /// Reconciles one media type. Returns true only if Drive was reachable AND
  /// every Drive file is now present locally. Lists the Drive folder ONCE, then
  /// downloads each missing file by id (no per-file re-listing).
  static Future<bool> _sweep({
    required Future<Directory> Function() dirProvider,
    required Future<List<Map<String, dynamic>>> Function(dynamic api) list,
    required Future<List<int>?> Function(dynamic api, String id) download,
    required String label,
  }) async {
    final Directory dir;
    try {
      dir = await dirProvider();
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (e) {
      AppLogger.warning('[MediaHydration] $label dir unavailable: $e');
      return false;
    }

    if (_cancelled) return false;

    // Clear any scratch left by a previous interrupted run before refetching.
    await MediaCache.cleanScratch(dir);

    final List<Map<String, dynamic>> driveFiles;
    try {
      final api = await DriveService.getDriveApi();
      driveFiles = await list(api);

      var allPresent = true;
      for (final f in driveFiles) {
        // Bail promptly if cancelled mid-sweep (e.g. the user signed out).
        if (_cancelled) return false;
        final name = f['name'] as String?;
        final id = f['id'] as String?;
        if (name == null || id == null) continue;

        // Already have a complete copy → never re-download, never overwrite.
        if (await File(p.join(dir.path, name)).exists()) continue;

        final got = await MediaCache.fetch(name, dir, (fileName, target) async {
          final bytes = await download(api, id);
          if (bytes == null) return false;
          await target.writeAsBytes(bytes);
          return true;
        });
        if (got == null) allPresent = false;
      }
      return allPresent;
    } catch (e) {
      // Offline / Drive not authorised / throttled — not an error, just retry
      // on a later launch. The flag stays pending.
      AppLogger.warning('[MediaHydration] $label sweep deferred: $e');
      return false;
    }
  }
}
