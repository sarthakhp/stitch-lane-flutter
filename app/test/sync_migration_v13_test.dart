import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Builds a v12-shaped schema (last released version before this feature).
  Future<Database> openV12(String path) async {
    return openDatabase(
      path,
      version: 12,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE customers (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone_number TEXT,
            description TEXT,
            created TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE orders (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            title TEXT,
            due_date TEXT NOT NULL,
            description TEXT,
            created TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            value INTEGER,
            is_paid INTEGER NOT NULL DEFAULT 0,
            image_paths TEXT NOT NULL DEFAULT '[]',
            payment_date TEXT,
            payments TEXT NOT NULL DEFAULT '[]',
            total_paid_amount INTEGER NOT NULL DEFAULT 0,
            audio_file_path TEXT,
            audio_file_paths TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE measurements (
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            description TEXT NOT NULL,
            created TEXT NOT NULL,
            modified TEXT NOT NULL,
            audio_file_path TEXT,
            audio_file_paths TEXT,
            structured_data TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            due_date_warning_threshold INTEGER NOT NULL DEFAULT 3
          )
        ''');
      },
    );
  }

  // Upgrades to v13 (adds the three sync tables).
  Future<Database> upgradeToV13(String path) async {
    return openDatabase(
      path,
      version: 13,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 13) {
          await db.execute('''
            CREATE TABLE sync_outbox (
              collection   TEXT NOT NULL,
              entity_id    TEXT NOT NULL,
              op           TEXT NOT NULL,
              enqueued_at  INTEGER NOT NULL,
              PRIMARY KEY (collection, entity_id)
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_meta (
              key   TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_quarantine (
              id             TEXT PRIMARY KEY,
              collection     TEXT NOT NULL,
              entity_id      TEXT NOT NULL,
              op             TEXT NOT NULL,
              payload        TEXT,
              reason         TEXT NOT NULL,
              quarantined_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  test('v12→v13 migration: existing rows survive, new tables created', () async {
    // Must be a real file so the second open sees the schema from the first.
    final dir = Directory.systemTemp.createTempSync('sync_migration_test_');
    final path = p.join(dir.path, 'test.db');

    // Seed v12 data.
    final v12 = await openV12(path);
    await v12.insert('customers',
        {'id': 'cust-1', 'name': 'Test', 'created': '2026-01-01T00:00:00.000'});
    await v12.insert('orders', {
      'id': 'ord-1',
      'customer_id': 'cust-1',
      'due_date': '2026-02-01T00:00:00.000',
      'created': '2026-01-01T00:00:00.000',
      'status': 'pending',
      'is_paid': 0,
      'image_paths': '[]',
      'payments': '[]',
      'total_paid_amount': 0,
    });
    await v12.close();

    // Upgrade to v13.
    final v13 = await upgradeToV13(path);

    // Existing data intact.
    final customers = await v13.query('customers');
    expect(customers, hasLength(1));
    expect(customers.first['name'], 'Test');

    final orders = await v13.query('orders');
    expect(orders, hasLength(1));
    expect(orders.first['id'], 'ord-1');

    // New tables exist and are empty.
    final outbox = await v13.query('sync_outbox');
    expect(outbox, isEmpty);

    final meta = await v13.query('sync_meta');
    expect(meta, isEmpty);

    final quarantine = await v13.query('sync_quarantine');
    expect(quarantine, isEmpty);

    // New tables accept inserts.
    await v13.insert('sync_meta', {'key': 'device_id', 'value': 'test-uuid'});
    final after = await v13.query('sync_meta');
    expect(after.first['value'], 'test-uuid');

    await v13.close();
    dir.deleteSync(recursive: true);
  });
}
