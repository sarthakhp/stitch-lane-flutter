import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import '../../utils/app_logger.dart';
import 'sqlite_database.dart';

/// Information about a single rotating local snapshot of the live SQLite DB.
class DbSnapshot {
  /// Directory holding the snapshot's `.db` (+ optional `-wal`, `-shm`) files.
  final Directory dir;

  /// When the snapshot was taken (parsed from the directory name).
  final DateTime takenAt;

  /// Sum of all files in [dir]. Useful for UI display.
  final int sizeBytes;

  const DbSnapshot({
    required this.dir,
    required this.takenAt,
    required this.sizeBytes,
  });

  String get name => basename(dir.path);
}

/// Local rotating snapshots of the SQLite database — defense-in-depth for
/// device-side data loss.
///
/// Defends against:
///   - bad schema migrations (snapshot is taken BEFORE the migration runs)
///   - accidental data wipes (signing key mismatch, manual file edits, etc.)
///   - Drive-restore overwriting newer local data
///   - any future data event we haven't anticipated yet
///
/// Snapshots live alongside the main DB at
///   <getDatabasesPath()>/snapshots/<YYYY-MM-DDTHH-MM-SS>/
/// with copies of stitch_genie.db plus -wal and -shm if present. WAL mode
/// puts the most recent writes in -wal until SQLite checkpoints them, so we
/// always copy the WAL too — otherwise a snapshot would silently miss the
/// last few minutes of data.
///
/// Cost on disk: ~260KB per snapshot × [maxSnapshots] = ~5MB total. Trivial.
class DbSnapshotService {
  DbSnapshotService._();

  /// Maximum number of snapshots to keep on disk. Older ones are pruned in
  /// FIFO order each time a new snapshot is taken.
  static const int maxSnapshots = 20;

  /// Don't snapshot more than once per this interval — opening the app 50
  /// times in a row shouldn't blow through the retention budget within an
  /// hour. One snapshot per launch, capped at this frequency.
  static const Duration minInterval = Duration(minutes: 30);

  static const String _snapshotsSubdir = 'snapshots';

  /// Takes a snapshot of the live database, if one hasn't been taken in
  /// [minInterval]. Call this once at app startup, **before** any database
  /// open / migration — that way even a buggy migration leaves the
  /// pre-migration state recoverable.
  ///
  /// Silently no-ops on first launch (no DB file exists yet). Errors are
  /// logged but never rethrown — a failed snapshot must not block app boot.
  static Future<void> snapshotBeforeOpen() async {
    try {
      final dbPath = await getDatabasesPath();
      final liveDb = File(join(dbPath, SqliteDatabase.dbName));
      if (!await liveDb.exists()) {
        // First launch — nothing yet to snapshot.
        return;
      }

      final snapshotsRoot = Directory(join(dbPath, _snapshotsSubdir));
      await snapshotsRoot.create(recursive: true);

      if (await _hasRecentSnapshot(snapshotsRoot)) {
        AppLogger.info(
          'DbSnapshotService: skipping — recent snapshot within ${minInterval.inMinutes}m',
        );
        return;
      }

      final ts = _formatTimestamp(DateTime.now());
      final snapshotDir = Directory(join(snapshotsRoot.path, ts));
      await snapshotDir.create(recursive: true);

      // Copy main DB + WAL + SHM (whichever exist).
      var copied = 0;
      for (final suffix in ['', '-wal', '-shm']) {
        final src = File(join(dbPath, '${SqliteDatabase.dbName}$suffix'));
        if (await src.exists()) {
          await src.copy(
            join(snapshotDir.path, '${SqliteDatabase.dbName}$suffix'),
          );
          copied++;
        }
      }

      await _pruneTo(snapshotsRoot, keep: maxSnapshots);
      AppLogger.info(
        'DbSnapshotService: snapshot $ts ($copied files copied)',
      );
    } catch (e, st) {
      // Never throw from a snapshot — boot must continue regardless.
      AppLogger.error('DbSnapshotService: snapshot failed', e, st);
    }
  }

  /// Forces a snapshot now, ignoring [minInterval]. Used by the "Snapshot
  /// now" button on the Developer screen — when the user is about to do
  /// something risky and wants a known-good restore point.
  ///
  /// Returns the new snapshot, or null on failure (e.g. live DB missing).
  static Future<DbSnapshot?> snapshotNow() async {
    try {
      final dbPath = await getDatabasesPath();
      final liveDb = File(join(dbPath, SqliteDatabase.dbName));
      if (!await liveDb.exists()) return null;

      final snapshotsRoot = Directory(join(dbPath, _snapshotsSubdir));
      await snapshotsRoot.create(recursive: true);

      final ts = _formatTimestamp(DateTime.now());
      final snapshotDir = Directory(join(snapshotsRoot.path, ts));
      await snapshotDir.create(recursive: true);

      for (final suffix in ['', '-wal', '-shm']) {
        final src = File(join(dbPath, '${SqliteDatabase.dbName}$suffix'));
        if (await src.exists()) {
          await src.copy(
            join(snapshotDir.path, '${SqliteDatabase.dbName}$suffix'),
          );
        }
      }

      await _pruneTo(snapshotsRoot, keep: maxSnapshots);
      AppLogger.info('DbSnapshotService: manual snapshot $ts taken');

      final list = await listSnapshots();
      return list.isEmpty ? null : list.first;
    } catch (e, st) {
      AppLogger.error('DbSnapshotService: manual snapshot failed', e, st);
      return null;
    }
  }

  /// Returns all snapshots on disk, newest first.
  static Future<List<DbSnapshot>> listSnapshots() async {
    try {
      final dbPath = await getDatabasesPath();
      final root = Directory(join(dbPath, _snapshotsSubdir));
      if (!await root.exists()) return const [];

      final result = <DbSnapshot>[];
      await for (final entity in root.list()) {
        if (entity is! Directory) continue;
        final mainDb = File(join(entity.path, SqliteDatabase.dbName));
        if (!await mainDb.exists()) continue;

        final takenAt = _parseTimestamp(basename(entity.path)) ??
            (await mainDb.stat()).modified;

        // Total size = sum of all files in the snapshot directory.
        var size = 0;
        await for (final f in entity.list()) {
          if (f is File) size += (await f.stat()).size;
        }
        result.add(
          DbSnapshot(dir: entity, takenAt: takenAt, sizeBytes: size),
        );
      }
      result.sort((a, b) => b.takenAt.compareTo(a.takenAt));
      return result;
    } catch (e, st) {
      AppLogger.error('DbSnapshotService: list failed', e, st);
      return const [];
    }
  }

  /// Overlays the files from [snapshot] onto the live DB position.
  ///
  /// The caller MUST close the live database first (via
  /// `SqliteDatabase.close()`) and MUST trigger an app restart afterwards —
  /// in-memory caches and Provider state will be stale otherwise. The
  /// Developer-screen UI handles both.
  ///
  /// Returns true on success.
  static Future<bool> restoreFromSnapshot(DbSnapshot snapshot) async {
    try {
      final dbPath = await getDatabasesPath();

      // Defensively remove any -wal / -shm of the LIVE DB before copying.
      // A stale WAL pointing at the old main DB would corrupt the restored
      // DB the next time SQLite opens it.
      for (final suffix in ['-wal', '-shm']) {
        final stale = File(join(dbPath, '${SqliteDatabase.dbName}$suffix'));
        if (await stale.exists()) {
          await stale.delete();
        }
      }

      // Now overlay snapshot files into the live position.
      for (final suffix in ['', '-wal', '-shm']) {
        final src = File(
          join(snapshot.dir.path, '${SqliteDatabase.dbName}$suffix'),
        );
        if (await src.exists()) {
          await src.copy(join(dbPath, '${SqliteDatabase.dbName}$suffix'));
        }
      }

      AppLogger.info(
        'DbSnapshotService: restored from ${basename(snapshot.dir.path)}',
      );
      return true;
    } catch (e, st) {
      AppLogger.error('DbSnapshotService: restore failed', e, st);
      return false;
    }
  }

  /// Deletes a single snapshot directory. Useful from the Developer screen.
  static Future<bool> deleteSnapshot(DbSnapshot snapshot) async {
    try {
      await snapshot.dir.delete(recursive: true);
      return true;
    } catch (e, st) {
      AppLogger.error('DbSnapshotService: delete failed', e, st);
      return false;
    }
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// True if any snapshot is younger than [minInterval]. Skips throttling
  /// when no snapshots exist at all.
  static Future<bool> _hasRecentSnapshot(Directory snapshotsRoot) async {
    final cutoff = DateTime.now().subtract(minInterval);
    await for (final entity in snapshotsRoot.list()) {
      if (entity is! Directory) continue;
      final takenAt = _parseTimestamp(basename(entity.path));
      if (takenAt != null && takenAt.isAfter(cutoff)) return true;
    }
    return false;
  }

  /// Deletes oldest snapshots so only [keep] remain. Unparseable directory
  /// names get sorted to the start (deleted first), which is a safe choice
  /// for stragglers from older formats.
  static Future<void> _pruneTo(
    Directory snapshotsRoot, {
    required int keep,
  }) async {
    final dirs = <Directory>[];
    await for (final entity in snapshotsRoot.list()) {
      if (entity is Directory) dirs.add(entity);
    }
    dirs.sort((a, b) {
      final ta = _parseTimestamp(basename(a.path));
      final tb = _parseTimestamp(basename(b.path));
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1; // unparseable → first to be deleted
      if (tb == null) return 1;
      return ta.compareTo(tb); // oldest first
    });
    while (dirs.length > keep) {
      final victim = dirs.removeAt(0);
      try {
        await victim.delete(recursive: true);
      } catch (e) {
        AppLogger.warning(
          'DbSnapshotService: failed to prune ${victim.path}: $e',
        );
      }
    }
  }

  /// Filename-safe ISO-ish timestamp: 2026-05-29T09-15-23. No colons or
  /// spaces — those are invalid on some Android filesystem layers.
  static String _formatTimestamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}T'
        '${two(t.hour)}-${two(t.minute)}-${two(t.second)}';
  }

  static DateTime? _parseTimestamp(String name) {
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})$',
    ).firstMatch(name);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  }
}
