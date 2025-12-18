import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';
import '../../backend/repositories/order_repository.dart';
import '../state/order_state.dart';

class OrderService {
  static Future<void> loadOrders(
    OrderState state,
    OrderRepository repository,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      final orders = await repository.getAllOrders();
      state.setOrders(orders);
    } catch (e) {
      state.setError('Failed to load orders: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> loadOrdersByCustomerId(
    OrderState state,
    OrderRepository repository,
    String customerId,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      final orders = await repository.getOrdersByCustomerId(customerId);
      state.setOrders(orders);
    } catch (e) {
      state.setError('Failed to load orders: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> addOrder(
    OrderState state,
    OrderRepository repository,
    Order order,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.addOrder(order);
      state.addOrder(order);
    } catch (e) {
      state.setError('Failed to add order: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> updateOrder(
    OrderState state,
    OrderRepository repository,
    Order order,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.updateOrder(order);
      state.updateOrder(order);
    } catch (e) {
      state.setError('Failed to update order: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> deleteOrder(
    OrderState state,
    OrderRepository repository,
    String id,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.deleteOrder(id);
      state.removeOrder(id);
    } catch (e) {
      state.setError('Failed to delete order: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static int getPendingOrdersCount(List<Order> orders) {
    return orders.where((order) => order.status == OrderStatus.pending).length;
  }

  static int getCustomersWithPendingOrdersCount(List<Order> orders) {
    final customerIds = orders
        .where((order) => order.status == OrderStatus.pending)
        .map((order) => order.customerId)
        .toSet();
    return customerIds.length;
  }

  static int getTotalUnpaidAmount(List<Order> orders) {
    return orders
        .where((order) => !order.isPaid)
        .fold(0, (sum, order) => sum + order.value);
  }
}

