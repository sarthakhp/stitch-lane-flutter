import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/sqlite_database.dart';

/// One set-aside write that could not be synced because this device was fenced
/// (a newer writer took over). Holds a JSON [payload] snapshot of the row so it
/// can be reviewed — nothing the user typed is ever discarded silently.
@immutable
class QuarantineRow {
  final String collection;
  final String entityId;
  final String op;
  final String? payload;
  final String reason;
  final int quarantinedAt;

  const QuarantineRow({
    required this.collection,
    required this.entityId,
    required this.op,
    required this.payload,
    required this.reason,
    required this.quarantinedAt,
  });
}

/// Holdover store for writes a fenced device couldn't push. The fence path moves
/// every pending outbox row here (with a payload snapshot) before clearing the
/// outbox, so a "Changes that couldn't sync (N)" review screen can surface them
/// and the user decides what to do — they are never lost on their own.
class SyncQuarantine {
  SyncQuarantine._();

  static const String table = 'sync_quarantine';

  static const String _id = 'id';
  static const String _collection = 'collection';
  static const String _entityId = 'entity_id';
  static const String _op = 'op';
  static const String _payload = 'payload';
  static const String _reason = 'reason';
  static const String _quarantinedAt = 'quarantined_at';

  /// Records one quarantined write. Keyed by `collection:entityId` so requantining
  /// the same row replaces the prior entry rather than piling up duplicates.
  static Future<void> add({
    required String collection,
    required String entityId,
    required String op,
    required String? payload,
    required String reason,
  }) async {
    final db = await SqliteDatabase.database;
    await db.insert(
      table,
      {
        _id: '$collection:$entityId',
        _collection: collection,
        _entityId: entityId,
        _op: op,
        _payload: payload,
        _reason: reason,
        _quarantinedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> count() async {
    final db = await SqliteDatabase.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<QuarantineRow>> all() async {
    final db = await SqliteDatabase.database;
    final rows = await db.query(table, orderBy: '$_quarantinedAt DESC');
    return rows
        .map((r) => QuarantineRow(
              collection: r[_collection] as String,
              entityId: r[_entityId] as String,
              op: r[_op] as String,
              payload: r[_payload] as String?,
              reason: r[_reason] as String,
              quarantinedAt: r[_quarantinedAt] as int,
            ))
        .toList();
  }

  /// Discards all reviewed entries (the user has dealt with them).
  static Future<void> clear() async {
    final db = await SqliteDatabase.database;
    await db.delete(table);
  }
}
