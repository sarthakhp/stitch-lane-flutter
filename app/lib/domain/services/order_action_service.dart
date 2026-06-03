import 'package:uuid/uuid.dart';

import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';
import '../../backend/models/payment_entry.dart';
import '../../backend/repositories/order_repository.dart';
import '../state/order_state.dart';
import 'order_service.dart';

/// Single-field order mutations with explicit targets. AI-agnostic primitives
/// (also reusable by the normal UI). Each persists through
/// [OrderService.updateOrder] so state + repository stay in sync and the
/// `isPaid` cache is recomputed from the derived rule.
class OrderActionService {
  OrderActionService._();

  static Future<Order> setStatus(
    OrderState state,
    OrderRepository repository,
    Order order,
    OrderStatus status,
  ) async {
    final updated = order.copyWith(status: status);
    await OrderService.updateOrder(state, repository, updated);
    return updated;
  }

  /// Adds a payment dated today. [amount] null pays the full remaining.
  /// Recomputes `totalPaidAmount` and the `isPaid` cache from the new list.
  static Future<Order> recordPayment(
    OrderState state,
    OrderRepository repository,
    Order order, {
    int? amount,
  }) async {
    final pay = amount ?? order.outstanding;
    final entry = PaymentEntry(id: const Uuid().v4(), date: _today(), amount: pay);
    final payments = [...order.payments, entry];
    final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
    final updated = order
        .copyWith(payments: payments, totalPaidAmount: totalPaid);
    final withPaidFlag = updated.copyWith(isPaid: updated.isFullyPaid);
    await OrderService.updateOrder(state, repository, withPaidFlag);
    return withPaidFlag;
  }

  static Future<Order> setPrice(
    OrderState state,
    OrderRepository repository,
    Order order,
    int value,
  ) async {
    final updated = order.copyWith(value: value);
    final withPaidFlag = updated.copyWith(isPaid: updated.isFullyPaid);
    await OrderService.updateOrder(state, repository, withPaidFlag);
    return withPaidFlag;
  }

  static Future<Order> setDueDate(
    OrderState state,
    OrderRepository repository,
    Order order,
    DateTime dueDate,
  ) async {
    final updated = order.copyWith(dueDate: dueDate);
    await OrderService.updateOrder(state, repository, updated);
    return updated;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
