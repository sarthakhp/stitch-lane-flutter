import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../models/measurement.dart';
import '../util/audio_path_list.dart';
import '../database/sqlite_database.dart';
import 'measurement_repository.dart';
import 'sync_outbox.dart';

class SqliteMeasurementRepository implements MeasurementRepository {
  Future<Database> get _db => SqliteDatabase.database;

  @override
  Future<List<Measurement>> getAllMeasurements() async {
    try {
      final db = await _db;
      final maps = await db.query('measurements');
      return maps.map(fromMap).toList();
    } catch (e) {
      throw Exception('Failed to get measurements: $e');
    }
  }

  @override
  Future<List<Measurement>> getMeasurementsByCustomerId(String customerId) async {
    try {
      final db = await _db;
      final maps = await db.query('measurements',
          where: 'customer_id = ?', whereArgs: [customerId]);
      return maps.map(fromMap).toList();
    } catch (e) {
      throw Exception('Failed to get measurements for customer: $e');
    }
  }

  @override
  Future<Measurement?> getMeasurementById(String id) async {
    try {
      final db = await _db;
      final maps = await db.query('measurements', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addMeasurement(Measurement measurement) async {
    try {
      final db = await _db;
      await db.insert('measurements', toMap(measurement),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await SyncOutbox.enqueue(
          'measurements', measurement.id, SyncOutbox.opUpsert);
    } catch (e) {
      throw Exception('Failed to add measurement: $e');
    }
  }

  @override
  Future<void> updateMeasurement(Measurement measurement) async {
    try {
      final db = await _db;
      final count = await db.update('measurements', toMap(measurement),
          where: 'id = ?', whereArgs: [measurement.id]);
      if (count == 0) throw Exception('Measurement not found');
      await SyncOutbox.enqueue(
          'measurements', measurement.id, SyncOutbox.opUpsert);
    } catch (e) {
      throw Exception('Failed to update measurement: $e');
    }
  }

  @override
  Future<void> deleteMeasurement(String id) async {
    try {
      final db = await _db;
      await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
      await SyncOutbox.enqueue('measurements', id, SyncOutbox.opDelete);
    } catch (e) {
      throw Exception('Failed to delete measurement: $e');
    }
  }

  @override
  Future<void> deleteMeasurementsByCustomerId(String customerId) async {
    try {
      final db = await _db;
      // Enumerate ids before deleting so each removed measurement can be
      // enqueued for the mirror; one transaction keeps the enqueues atomic.
      await db.transaction((txn) async {
        final ids = await txn.query('measurements',
            columns: ['id'], where: 'customer_id = ?', whereArgs: [customerId]);
        await txn.delete('measurements',
            where: 'customer_id = ?', whereArgs: [customerId]);
        for (final row in ids) {
          await SyncOutbox.enqueueOn(
              txn, 'measurements', row['id'] as String, SyncOutbox.opDelete);
        }
      });
    } catch (e) {
      throw Exception('Failed to delete measurements for customer: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _db;
      await db.delete('measurements');
    } catch (e) {
      throw Exception('Failed to clear measurements: $e');
    }
  }

  @override
  Future<void> upsertFromSync(Measurement measurement) async {
    final db = await _db;
    await db.insert('measurements', toMap(measurement),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteFromSync(String id) async {
    final db = await _db;
    await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> deleteAllExcept(Iterable<String> keepIds) async {
    final db = await _db;
    final keep = keepIds.toSet();
    final rows = await db.query('measurements', columns: ['id']);
    final stale = rows
        .map((r) => r['id'] as String)
        .where((id) => !keep.contains(id))
        .toList();
    var deleted = 0;
    for (final id in stale) {
      deleted +=
          await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
    }
    return deleted;
  }

  static Map<String, dynamic> toMap(Measurement m) => {
        'id': m.id,
        'customer_id': m.customerId,
        'description': m.description,
        'created': m.created.toIso8601String(),
        'modified': m.modified.toIso8601String(),
        'audio_file_paths': AudioPathList.encode(m.audioFilePaths),
        'structured_data':
            m.structuredData == null ? null : jsonEncode(m.structuredData),
      };

  static Measurement fromMap(Map<String, dynamic> map) {
    final rawStructured = map['structured_data'];
    Map<String, dynamic>? structured;
    if (rawStructured is String && rawStructured.isNotEmpty) {
      final decoded = jsonDecode(rawStructured);
      if (decoded is Map) {
        structured = Map<String, dynamic>.from(decoded);
      }
    }
    return Measurement(
      id: map['id'] as String,
      customerId: map['customer_id'] as String,
      description: map['description'] as String,
      created: DateTime.parse(map['created'] as String),
      modified: DateTime.parse(map['modified'] as String),
      audioFilePaths: AudioPathList.read(
        map['audio_file_paths'],
        legacySingle: map['audio_file_path'],
      ),
      structuredData: structured,
    );
  }
}
