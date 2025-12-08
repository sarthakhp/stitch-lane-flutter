import 'package:hive/hive.dart';
import '../models/order.dart';
import '../database/database_service.dart';
import 'order_repository.dart';

class HiveOrderRepository implements OrderRepository {
  Box<Order> get _box => DatabaseService.getOrdersBox();

  @override
  Future<List<Order>> getAllOrders() async {
    try {
      return _box.values.toList();
    } catch (e) {
      throw Exception('Failed to get orders: $e');
    }
  }

  @override
  Future<List<Order>> getOrdersByCustomerId(String customerId) async {
    try {
      return _box.values
          .where((order) => order.customerId == customerId)
          .toList();
    } catch (e) {
      throw Exception('Failed to get orders for customer: $e');
    }
  }

  @override
  Future<Order?> getOrderById(String id) async {
    try {
      return _box.values.firstWhere(
        (order) => order.id == id,
        orElse: () => throw Exception('Order not found'),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addOrder(Order order) async {
    try {
      await _box.put(order.id, order);
    } catch (e) {
      throw Exception('Failed to add order: $e');
    }
  }

  @override
  Future<void> updateOrder(Order order) async {
    try {
      if (_box.containsKey(order.id)) {
        await _box.put(order.id, order);
      } else {
        throw Exception('Order not found');
      }
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  @override
  Future<void> deleteOrdersByCustomerId(String customerId) async {
    try {
      final ordersToDelete = _box.values
          .where((order) => order.customerId == customerId)
          .map((order) => order.id)
          .toList();

      for (final orderId in ordersToDelete) {
        await _box.delete(orderId);
      }
    } catch (e) {
      throw Exception('Failed to delete orders for customer: $e');
    }
  }
}

