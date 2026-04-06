import 'package:sqflite/sqflite.dart';
import '../models/measurement.dart';
import '../database/sqlite_database.dart';
import 'measurement_repository.dart';

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
    } catch (e) {
      throw Exception('Failed to update measurement: $e');
    }
  }

  @override
  Future<void> deleteMeasurement(String id) async {
    try {
      final db = await _db;
      await db.delete('measurements', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete measurement: $e');
    }
  }

  @override
  Future<void> deleteMeasurementsByCustomerId(String customerId) async {
    try {
      final db = await _db;
      await db.delete('measurements', where: 'customer_id = ?', whereArgs: [customerId]);
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

  static Map<String, dynamic> toMap(Measurement m) => {
        'id': m.id,
        'customer_id': m.customerId,
        'description': m.description,
        'created': m.created.toIso8601String(),
        'modified': m.modified.toIso8601String(),
        'audio_file_path': m.audioFilePath,
      };

  static Measurement fromMap(Map<String, dynamic> map) => Measurement(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        description: map['description'] as String,
        created: DateTime.parse(map['created'] as String),
        modified: DateTime.parse(map['modified'] as String),
        audioFilePath: map['audio_file_path'] as String?,
      );
}
