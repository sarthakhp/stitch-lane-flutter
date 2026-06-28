import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/services/sync/sync_config.dart';
import '../database/sqlite_database.dart';

/// One pending publish/delete intent read back from `sync_outbox`.
@immutable
class OutboxRow {
  final String collection;
  final String entityId;
  final String op;
  final int enqueuedAt;

  const OutboxRow({
    required this.collection,
    required this.entityId,
    required this.op,
    required this.enqueuedAt,
  });
}

/// The writer-side publish/delete intent log.
///
/// Every local mutation on a synced entity records one row here, keyed by
/// `(collection, entity_id)` so repeated edits to the same row coalesce into a
/// single pending op (and a later `delete` supersedes a queued `upsert`). The
/// push pump drains it to Firestore and removes each row on ack; anything left
/// behind is retried on the next run, so the outbox doubles as the offline
/// reconciliation backstop.
///
/// Every entry point is a no-op while sync is disabled, so a flag-off build
/// never writes to `sync_outbox` and behaves exactly like today.
class SyncOutbox {
  SyncOutbox._();

  static const String table = 'sync_outbox';
  static const String opUpsert = 'upsert';
  static const String opDelete = 'delete';

  static const String _collection = 'collection';
  static const String _entityId = 'entity_id';
  static const String _op = 'op';
  static const String _enqueuedAt = 'enqueued_at';

  /// Bumps on every successful enqueue so the push pump can schedule a drain
  /// "after a write" without the repos knowing about the pump. Listeners should
  /// debounce — a burst of edits bumps this many times.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Records an intent to publish (`op: upsert`) or remove (`op: delete`) [id]
  /// in [collection], acquiring its own DB handle. Use this from non-atomic
  /// single-row mutations.
  static Future<void> enqueue(String collection, String id, String op) async {
    if (!SyncConfig.enabled) return;
    final db = await SqliteDatabase.database;
    await _write(db, collection, id, op);
    revision.value++;
  }

  /// Same as [enqueue] but on an existing [executor] — call this from inside a
  /// repo transaction (e.g. a cascade delete) so the enqueue commits atomically
  /// with the rows it describes.
  static Future<void> enqueueOn(
    DatabaseExecutor executor,
    String collection,
    String id,
    String op,
  ) async {
    if (!SyncConfig.enabled) return;
    await _write(executor, collection, id, op);
    revision.value++;
  }

  /// Unconditional enqueue for the one-time backfill (publish-all on becoming
  /// primary). Unlike [enqueue] this is NOT gated on [SyncConfig.enabled],
  /// because backfill is the deliberate act of turning sync on — it must record
  /// every row regardless of flag-init ordering. Never call this from normal
  /// repo writes; those stay flag-guarded so a flag-off build is inert.
  static Future<void> enqueueForBackfill(String collection, String id) async {
    final db = await SqliteDatabase.database;
    await _write(db, collection, id, opUpsert);
  }

  /// All pending rows, oldest first (the order they should be pushed in).
  static Future<List<OutboxRow>> pending() async {
    final db = await SqliteDatabase.database;
    final rows = await db.query(table, orderBy: '$_enqueuedAt ASC');
    return rows
        .map((r) => OutboxRow(
              collection: r[_collection] as String,
              entityId: r[_entityId] as String,
              op: r[_op] as String,
              enqueuedAt: r[_enqueuedAt] as int,
            ))
        .toList();
  }

  /// Removes a single acked row. No-op if it was already coalesced away.
  static Future<void> remove(String collection, String id) async {
    final db = await SqliteDatabase.database;
    await db.delete(
      table,
      where: '$_collection = ? AND $_entityId = ?',
      whereArgs: [collection, id],
    );
  }

  /// Empties the outbox. Used by the fence path after pending rows have been
  /// moved to [SyncQuarantine] — nothing is dropped silently.
  static Future<void> clear() async {
    final db = await SqliteDatabase.database;
    await db.delete(table);
  }

  /// Current number of pending rows — published into the control doc as
  /// `pendingCount` so a reader can gate handoff on a fully-drained writer.
  static Future<int> count() async {
    final db = await SqliteDatabase.database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> _write(
    DatabaseExecutor executor,
    String collection,
    String id,
    String op,
  ) async {
    await executor.insert(
      table,
      {
        _collection: collection,
        _entityId: id,
        _op: op,
        _enqueuedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
