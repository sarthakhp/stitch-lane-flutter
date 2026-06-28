import '../models/order.dart';

abstract class OrderRepository {
  Future<List<Order>> getAllOrders();
  Future<List<Order>> getOrdersByCustomerId(String customerId);
  Future<Order?> getOrderById(String id);
  Future<void> addOrder(Order order);
  Future<void> updateOrder(Order order);
  Future<void> deleteOrder(String id);
  Future<void> deleteOrdersByCustomerId(String customerId);

  Future<void> clearAll();

  // ── reader mirror path (never enqueues to the sync outbox) ────────────────

  /// Insert-or-replace a row received from the cloud. Unlike [addOrder] this
  /// records no outbox intent, so a reader's mirror never becomes dirty.
  Future<void> upsertFromSync(Order order);

  /// Delete a single row received as a cloud removal. No cascade, no enqueue.
  Future<void> deleteFromSync(String id);

  /// Cold-start reconcile: drop every local row whose id is not in [keepIds].
  /// Returns the number of rows removed. Never enqueues.
  Future<int> deleteAllExcept(Iterable<String> keepIds);
}

