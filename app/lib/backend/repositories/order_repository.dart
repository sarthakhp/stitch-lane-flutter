import '../models/order.dart';

abstract class OrderRepository {
  Future<List<Order>> getAllOrders();
  Future<List<Order>> getOrdersByCustomerId(String customerId);
  Future<Order?> getOrderById(String id);
  Future<void> addOrder(Order order);
  Future<void> updateOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<void> deleteOrdersByCustomerId(String customerId);
}

