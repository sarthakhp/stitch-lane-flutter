import 'package:sqflite/sqflite.dart';

import '../database/sqlite_database.dart';
import 'sync_meta_repository.dart';

class SqliteSyncMetaRepository implements SyncMetaRepository {
  Future<Database> get _db => SqliteDatabase.database;

  @override
  Future<String?> get(String key) async {
    final db = await _db;
    final rows = await db.query('sync_meta',
        columns: ['value'], where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> set(String key, String value) async {
    final db = await _db;
    await db.insert('sync_meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> remove(String key) async {
    final db = await _db;
    await db.delete('sync_meta', where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('sync_meta');
  }
}
