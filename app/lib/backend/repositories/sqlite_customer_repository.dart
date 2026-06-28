import 'package:sqflite/sqflite.dart';
import '../models/customer.dart';
import '../database/sqlite_database.dart';
import 'customer_repository.dart';
import 'sync_outbox.dart';

class SqliteCustomerRepository implements CustomerRepository {
  Future<Database> get _db => SqliteDatabase.database;

  @override
  Future<List<Customer>> getAllCustomers() async {
    try {
      final db = await _db;
      final maps = await db.query('customers');
      return maps.map(fromMap).toList();
    } catch (e) {
      throw Exception('Failed to get customers: $e');
    }
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    try {
      final db = await _db;
      final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addCustomer(Customer customer) async {
    try {
      final db = await _db;
      await db.insert('customers', toMap(customer),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await SyncOutbox.enqueue('customers', customer.id, SyncOutbox.opUpsert);
    } catch (e) {
      throw Exception('Failed to add customer: $e');
    }
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    try {
      final db = await _db;
      final count = await db.update('customers', toMap(customer),
          where: 'id = ?', whereArgs: [customer.id]);
      if (count == 0) throw Exception('Customer not found');
      await SyncOutbox.enqueue('customers', customer.id, SyncOutbox.opUpsert);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      final db = await _db;
      // Orders and measurements have a FK to customers, so deleting the
      // customer alone fails with a constraint error. Cascade-delete the
      // dependents first, all in one transaction.
      await db.transaction((txn) async {
        // Enumerate the child ids BEFORE deleting so the mirror can be told to
        // drop each one too — once deleted they're unrecoverable here.
        final orderIds = await txn.query('orders',
            columns: ['id'], where: 'customer_id = ?', whereArgs: [id]);
        final measurementIds = await txn.query('measurements',
            columns: ['id'], where: 'customer_id = ?', whereArgs: [id]);

        await txn.delete('orders', where: 'customer_id = ?', whereArgs: [id]);
        await txn.delete('measurements', where: 'customer_id = ?', whereArgs: [id]);
        await txn.delete('customers', where: 'id = ?', whereArgs: [id]);

        // Enqueue the deletes in the same transaction so they can never be lost
        // relative to the rows they describe.
        for (final row in orderIds) {
          await SyncOutbox.enqueueOn(
              txn, 'orders', row['id'] as String, SyncOutbox.opDelete);
        }
        for (final row in measurementIds) {
          await SyncOutbox.enqueueOn(
              txn, 'measurements', row['id'] as String, SyncOutbox.opDelete);
        }
        await SyncOutbox.enqueueOn(txn, 'customers', id, SyncOutbox.opDelete);
      });
    } catch (e) {
      throw Exception('Failed to delete customer: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _db;
      await db.delete('customers');
    } catch (e) {
      throw Exception('Failed to clear customers: $e');
    }
  }

  @override
  Future<void> upsertFromSync(Customer customer) async {
    final db = await _db;
    await db.insert('customers', toMap(customer),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteFromSync(String id) async {
    final db = await _db;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> deleteAllExcept(Iterable<String> keepIds) async {
    final db = await _db;
    final keep = keepIds.toSet();
    final rows = await db.query('customers', columns: ['id']);
    final stale = rows
        .map((r) => r['id'] as String)
        .where((id) => !keep.contains(id))
        .toList();
    var deleted = 0;
    for (final id in stale) {
      deleted += await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    }
    return deleted;
  }

  static Map<String, dynamic> toMap(Customer c) => {
        'id': c.id,
        'name': c.name,
        'phone_number': c.phoneNumber,
        'description': c.description,
        'created': c.created.toIso8601String(),
      };

  static Customer fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        name: map['name'] as String,
        phoneNumber: map['phone_number'] as String?,
        description: map['description'] as String?,
        created: DateTime.parse(map['created'] as String),
      );
}
