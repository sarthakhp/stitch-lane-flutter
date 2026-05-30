import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';
import '../../backend/repositories/order_repository.dart';
import '../state/order_state.dart';
import 'image_storage_service.dart';

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

  /// Persist a batch of orders in one call. Each order is written
  /// sequentially through [repository.addOrder] so a mid-batch failure
  /// surfaces immediately while still preserving the orders that succeeded.
  /// Returns the list of successfully-saved orders.
  static Future<List<Order>> addOrders(
    OrderState state,
    OrderRepository repository,
    List<Order> orders,
  ) async {
    if (orders.isEmpty) return const [];
    state.setLoading(true);
    state.clearError();

    final saved = <Order>[];
    try {
      for (final order in orders) {
        await repository.addOrder(order);
        state.addOrder(order);
        saved.add(order);
      }
      return saved;
    } catch (e) {
      state.setError('Failed to add orders: $e');
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
      final order = state.orders.firstWhere((o) => o.id == id);

      if (order.imagePaths.isNotEmpty) {
        await ImageStorageService.deleteImages(order.imagePaths);
      }

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
    return orders.fold(0, (sum, order) => sum + order.outstanding);
  }


  /// Single-pass O(N) computation of the three home-tab summary stats.
  /// Replaces 3 separate iterations over the order list.
  static HomeStats computeHomeStats(List<Order> orders) {
    int pendingCount = 0;
    int unpaidAmount = 0;
    final pendingCustomerIds = <String>{};

    for (final order in orders) {
      if (order.status == OrderStatus.pending) {
        pendingCount++;
        pendingCustomerIds.add(order.customerId);
      }
      unpaidAmount += order.outstanding;
    }

    return HomeStats(
      pendingOrdersCount: pendingCount,
      customersWithPendingOrdersCount: pendingCustomerIds.length,
      totalUnpaidAmount: unpaidAmount,
    );
  }

  static int calculateTotalPaidAmount(Order order) {
    return order.payments.fold(0, (sum, payment) => sum + payment.amount);
  }

  static int getRemainingAmount(Order order) => order.outstanding;

  static Future<Order> toggleOrderStatus(
    OrderState state,
    OrderRepository repository,
    Order order,
  ) async {
    final OrderStatus newStatus;

    switch (order.status) {
      case OrderStatus.pending:
        newStatus = OrderStatus.ready;
        break;
      case OrderStatus.ready:
        newStatus = OrderStatus.done;
        break;
      case OrderStatus.done:
        newStatus = OrderStatus.pending;
        break;
    }

    final updatedOrder = order.copyWith(status: newStatus);
    await updateOrder(state, repository, updatedOrder);
    return updatedOrder;
  }

  static String getStatusToggleMessage(OrderStatus newStatus) {
    switch (newStatus) {
      case OrderStatus.ready:
        return 'Order marked as ready';
      case OrderStatus.done:
        return 'Order marked as done';
      case OrderStatus.pending:
        return 'Order marked as pending';
    }
  }
}


/// Immutable summary of home-tab stats. Implements value equality so Provider's
/// Selector can skip rebuilds when the underlying numbers haven't changed.
class HomeStats {
  final int pendingOrdersCount;
  final int customersWithPendingOrdersCount;
  final int totalUnpaidAmount;

  const HomeStats({
    required this.pendingOrdersCount,
    required this.customersWithPendingOrdersCount,
    required this.totalUnpaidAmount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeStats &&
          pendingOrdersCount == other.pendingOrdersCount &&
          customersWithPendingOrdersCount ==
              other.customersWithPendingOrdersCount &&
          totalUnpaidAmount == other.totalUnpaidAmount;

  @override
  int get hashCode => Object.hash(
        pendingOrdersCount,
        customersWithPendingOrdersCount,
        totalUnpaidAmount,
      );
}

