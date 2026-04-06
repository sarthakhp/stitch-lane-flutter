import 'package:sqflite/sqflite.dart';
import '../models/customer.dart';
import '../database/sqlite_database.dart';
import 'customer_repository.dart';

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
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      final db = await _db;
      await db.delete('customers', where: 'id = ?', whereArgs: [id]);
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
