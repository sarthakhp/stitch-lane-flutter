import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/payment_entry.dart';
import '../util/audio_path_list.dart';
import '../database/sqlite_database.dart';
import 'order_repository.dart';

class SqliteOrderRepository implements OrderRepository {
  Future<Database> get _db => SqliteDatabase.database;

  @override
  Future<List<Order>> getAllOrders() async {
    try {
      final db = await _db;
      final maps = await db.query('orders');
      return maps.map(fromMap).toList();
    } catch (e) {
      throw Exception('Failed to get orders: $e');
    }
  }

  @override
  Future<List<Order>> getOrdersByCustomerId(String customerId) async {
    try {
      final db = await _db;
      final maps = await db.query('orders',
          where: 'customer_id = ?', whereArgs: [customerId]);
      return maps.map(fromMap).toList();
    } catch (e) {
      throw Exception('Failed to get orders for customer: $e');
    }
  }

  @override
  Future<Order?> getOrderById(String id) async {
    try {
      final db = await _db;
      final maps = await db.query('orders', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;
      return fromMap(maps.first);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addOrder(Order order) async {
    try {
      final db = await _db;
      await db.insert('orders', toMap(order),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      throw Exception('Failed to add order: $e');
    }
  }

  @override
  Future<void> updateOrder(Order order) async {
    try {
      final db = await _db;
      final count = await db.update('orders', toMap(order),
          where: 'id = ?', whereArgs: [order.id]);
      if (count == 0) throw Exception('Order not found');
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    try {
      final db = await _db;
      await db.delete('orders', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  @override
  Future<void> deleteOrdersByCustomerId(String customerId) async {
    try {
      final db = await _db;
      await db.delete('orders', where: 'customer_id = ?', whereArgs: [customerId]);
    } catch (e) {
      throw Exception('Failed to delete orders for customer: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await _db;
      await db.delete('orders');
    } catch (e) {
      throw Exception('Failed to clear orders: $e');
    }
  }

  static Map<String, dynamic> toMap(Order o) => {
        'id': o.id,
        'customer_id': o.customerId,
        'title': o.title,
        'due_date': o.dueDate.toIso8601String(),
        'description': o.description,
        'created': o.created.toIso8601String(),
        'status': o.status.name,
        'value': o.value,
        // is_paid is a denormalized cache — always recompute from the derived
        // rule on write so it can never drift from value/total_paid_amount.
        'is_paid': o.isFullyPaid ? 1 : 0,
        'image_paths': jsonEncode(o.imagePaths),
        'payment_date': o.paymentDate?.toIso8601String(),
        'payments': jsonEncode(o.payments.map((p) => p.toJson()).toList()),
        'total_paid_amount': o.totalPaidAmount,
        'audio_file_paths': AudioPathList.encode(o.audioFilePaths),
      };

  static Order fromMap(Map<String, dynamic> map) => Order(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        title: map['title'] as String?,
        dueDate: DateTime.parse(map['due_date'] as String),
        description: map['description'] as String?,
        created: DateTime.parse(map['created'] as String),
        status: OrderStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => OrderStatus.pending,
        ),
        value: map['value'] as int?,
        isPaid: (map['is_paid'] as int? ?? 0) == 1,
        imagePaths: List<String>.from(jsonDecode(map['image_paths'] as String? ?? '[]')),
        paymentDate: map['payment_date'] != null
            ? DateTime.parse(map['payment_date'] as String)
            : null,
        payments: (jsonDecode(map['payments'] as String? ?? '[]') as List)
            .map((p) => PaymentEntry.fromJson(p as Map<String, dynamic>))
            .toList(),
        totalPaidAmount: map['total_paid_amount'] as int? ?? 0,
        audioFilePaths: AudioPathList.read(
          map['audio_file_paths'],
          legacySingle: map['audio_file_path'],
        ),
      );
}
