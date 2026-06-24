import '../../backend/repositories/repository_factory.dart';
import '../../utils/app_logger.dart';
import 'audio_backup_recorder.dart';
import 'recordings/recording_store.dart';

/// Sweeps the audio backup directory for files that are no longer worth
/// keeping. A file is "worth keeping" if any persisted [Measurement] still
/// references its path. Anything not referenced gets a grace period before
/// being deleted so we don't pull the rug out from a user who hasn't yet
/// saved a measurement, or who hit an error and might still recover.
class AudioBackupCleanupService {
  /// `.wav` files NOT referenced by any measurement: deleted after this
  /// many days. Long enough to give the user weeks to recover audio they
  /// forgot to save against a measurement; short enough to avoid hoarding.
  static const Duration _orphanedWavGrace = Duration(days: 30);

  /// `.pcm` files without a `.wav` sibling: these are normally cleaned up
  /// inline by [AudioBackupRecorder.finalize], so a lingering .pcm means
  /// finalize crashed mid-way. Kept for a week in case the user wants to
  /// hand-recover, then deleted.
  static const Duration _stalePcmGrace = Duration(days: 7);

  /// Files modified within this window are NEVER touched — even if they
  /// look orphaned — to avoid racing with an active recording session.
  static const Duration _safetyMinAge = Duration(hours: 24);

  /// Sweep orphan files. Overrideable grace periods let the developer screen
  /// trigger an immediate purge by passing `Duration.zero`; defaults are the
  /// safe-for-production windows above.
  static Future<CleanupResult> runCleanup({
    Duration orphanedWavGrace = _orphanedWavGrace,
    Duration stalePcmGrace = _stalePcmGrace,
    Duration safetyMinAge = _safetyMinAge,
  }) async {
    var kept = 0;
    var deleted = 0;
    var bytesFreed = 0;

    try {
      final files = await AudioBackupRecorder.listBackups();
      if (files.isEmpty) {
        AppLogger.info('AudioBackupCleanup: no backup files found, nothing to do');
        return const CleanupResult(kept: 0, deleted: 0, bytesFreed: 0);
      }

      // A file is referenced if ANY measurement or order links it. Both can
      // hold multiple recordings now, so flatten every audioFilePaths list.
      final measurements =
          await RepositoryFactory.createMeasurementRepository().getAllMeasurements();
      final orders =
          await RepositoryFactory.createOrderRepository().getAllOrders();
      final referencedPaths = <String>{
        for (final m in measurements) ...m.audioFilePaths,
        for (final o in orders) ...o.audioFilePaths,
      };

      final now = DateTime.now();

      for (final file in files) {
        try {
          final stat = await file.stat();
          final age = now.difference(stat.modified);
          final path = file.path;

          // Sidecar metadata is managed with its recording — never sweep a
          // `.json` on its own (it's removed when its `.wav` is).
          if (path.endsWith('.json')) {
            continue;
          }

          // Don't touch anything recent — could still be active.
          if (age < safetyMinAge) {
            kept++;
            continue;
          }

          // Referenced by a measurement → keep forever.
          if (referencedPaths.contains(path)) {
            kept++;
            continue;
          }

          final isPcm = path.endsWith('.pcm');

          // A recording we captured debug metadata for is a kept artifact for
          // the Recordings debugger — never auto-delete it (the user prunes it
          // explicitly from that screen).
          if (!isPcm && await RecordingStore.hasSidecar(path)) {
            kept++;
            continue;
          }

          final grace = isPcm ? stalePcmGrace : orphanedWavGrace;
          if (age < grace) {
            kept++;
            continue;
          }

          final size = stat.size;
          if (isPcm) {
            await file.delete();
          } else {
            // Remove the wav and its sidecar (if any) together.
            await RecordingStore.deleteByWavPath(path);
          }
          deleted++;
          bytesFreed += size;
          AppLogger.info(
            'AudioBackupCleanup: deleted orphan ${file.uri.pathSegments.last} '
            '(${(size / 1024).toStringAsFixed(1)}KB, age ${age.inDays}d)',
          );
        } catch (e) {
          AppLogger.warning('AudioBackupCleanup: skip ${file.path}: $e');
        }
      }

      AppLogger.info(
        'AudioBackupCleanup: done — kept=$kept deleted=$deleted '
        'freed=${(bytesFreed / 1024 / 1024).toStringAsFixed(2)}MB',
      );
    } catch (e) {
      AppLogger.error('AudioBackupCleanup: failed', e);
    }

    return CleanupResult(kept: kept, deleted: deleted, bytesFreed: bytesFreed);
  }
}

class CleanupResult {
  final int kept;
  final int deleted;
  final int bytesFreed;

  const CleanupResult({required this.kept, required this.deleted, required this.bytesFreed});
}
