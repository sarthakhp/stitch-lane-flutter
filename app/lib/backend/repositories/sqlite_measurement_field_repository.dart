import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/sqlite_database.dart';
import '../models/measurement_field.dart';
import 'measurement_field_repository.dart';

class SqliteMeasurementFieldRepository implements MeasurementFieldRepository {
  Future<Database> get _db => SqliteDatabase.database;

  @override
  Future<List<MeasurementField>> getAll() async {
    final db = await _db;
    final maps = await db.query('measurement_fields', orderBy: 'sort_order ASC');
    return maps.map(fromMap).toList();
  }

  @override
  Future<void> add(MeasurementField field) async {
    final db = await _db;
    await db.insert('measurement_fields', toMap(field),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> update(MeasurementField field) async {
    final db = await _db;
    final count = await db.update('measurement_fields', toMap(field),
        where: 'id = ?', whereArgs: [field.id]);
    if (count == 0) throw Exception('Measurement field not found: ${field.id}');
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('measurement_fields', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> replaceAll(List<MeasurementField> fields) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('measurement_fields');
      for (final field in fields) {
        await txn.insert('measurement_fields', toMap(field));
      }
    });
  }

  @override
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('measurement_fields');
  }

  static Map<String, dynamic> toMap(MeasurementField f) => {
        'id': f.id,
        'label': f.label,
        'aliases': jsonEncode(f.aliases),
        'sort_order': f.sortOrder,
      };

  static MeasurementField fromMap(Map<String, dynamic> map) {
    final rawAliases = map['aliases'] as String? ?? '[]';
    final decoded = jsonDecode(rawAliases);
    return MeasurementField(
      id: map['id'] as String,
      label: map['label'] as String,
      aliases: decoded is List
          ? decoded.map((e) => e.toString()).toList()
          : const [],
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}
