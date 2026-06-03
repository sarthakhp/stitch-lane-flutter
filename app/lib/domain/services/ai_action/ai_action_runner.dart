import '../../../backend/models/order.dart';
import '../../../backend/models/order_status.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../state/order_state.dart';
import '../order_action_service.dart';
import 'action_labels.dart';
import 'proposed_action.dart';

/// Outcome of running a confirmed action — drives the card's result text and
/// the history note. [executedOrderIds] are the orders that changed.
class ActionResult {
  final bool ok;
  final String message;
  final List<String> executedOrderIds;

  const ActionResult(this.ok, this.message, {this.executedOrderIds = const []});
}

/// Executes a confirmed [ProposedAction] against the chosen orders. Re-fetches
/// each order first (chat data may be stale) and delegates the actual mutation
/// to [OrderActionService]. Pure of any UI/context — deps are passed in.
class AiActionRunner {
  AiActionRunner._();

  static Future<ActionResult> run(
    ProposedAction action, {
    required List<String> orderIds,
    required OrderState orderState,
    required OrderRepository orderRepo,
  }) async {
    final succeeded = <String>[];
    var lastMessage = '';
    var lastFailure = '';

    for (final orderId in orderIds) {
      final order = await orderRepo.getOrderById(orderId);
      if (order == null) {
        lastFailure = 'That order no longer exists.';
        continue;
      }
      final outcome = await _applyOne(action, order, orderState, orderRepo);
      if (outcome.ok) {
        succeeded.add(orderId);
        lastMessage = outcome.message;
      } else {
        lastFailure = outcome.message;
      }
    }

    // Single target → keep the detailed per-order message (balance, date…).
    if (orderIds.length == 1) {
      final ok = succeeded.isNotEmpty;
      return ActionResult(
        ok,
        ok ? lastMessage : lastFailure,
        executedOrderIds: succeeded,
      );
    }

    // Multiple targets → an aggregated summary.
    final failed = orderIds.length - succeeded.length;
    final summary = ActionLabels.resultSummary(action, succeeded.length);
    final message = failed == 0 ? summary : '$summary $failed failed.';
    return ActionResult(
      succeeded.isNotEmpty,
      message,
      executedOrderIds: succeeded,
    );
  }

  /// Applies the change to one already-fetched order.
  static Future<ActionResult> _applyOne(
    ProposedAction action,
    Order order,
    OrderState orderState,
    OrderRepository orderRepo,
  ) async {
    try {
      switch (action.kind) {
        case ProposedActionKind.setStatus:
          final target = _statusFrom(action.params['status'] as String?);
          if (order.status == target) {
            return ActionResult(
                true, 'Already ${ActionLabels.statusLabel(target.name)}.');
          }
          await OrderActionService.setStatus(
              orderState, orderRepo, order, target);
          return ActionResult(
              true, 'Marked as ${ActionLabels.statusLabel(target.name)}.');

        case ProposedActionKind.recordPayment:
          if (order.value == null) {
            return const ActionResult(
                false, 'Set a price before recording a payment.');
          }
          final amount = action.params['amount'] as int?;
          if (amount != null && amount <= 0) {
            return const ActionResult(
                false, 'Payment amount must be more than zero.');
          }
          final updated = await OrderActionService.recordPayment(
              orderState, orderRepo, order,
              amount: amount);
          final paid = updated.totalPaidAmount - order.totalPaidAmount;
          final tail = updated.isFullyPaid
              ? 'Fully paid.'
              : '₹${updated.outstanding} remaining.';
          return ActionResult(true, 'Recorded ₹$paid. $tail');

        case ProposedActionKind.setPrice:
          final value = action.params['value'] as int? ?? 0;
          if (value < 0) {
            return const ActionResult(false, 'Price cannot be negative.');
          }
          await OrderActionService.setPrice(orderState, orderRepo, order, value);
          return ActionResult(true, 'Price set to ₹$value.');

        case ProposedActionKind.setDueDate:
          final iso = action.params['dueDate'] as String?;
          final date = iso == null ? null : DateTime.tryParse(iso);
          if (date == null) {
            return const ActionResult(false, 'Could not read that date.');
          }
          await OrderActionService.setDueDate(orderState, orderRepo, order, date);
          return ActionResult(
              true, 'Due date set to ${ActionLabels.prettyDate(iso)}.');
      }
    } catch (_) {
      return const ActionResult(
          false, 'Could not apply the change. Please try again.');
    }
  }

  static OrderStatus _statusFrom(String? name) => OrderStatus.values
      .firstWhere((e) => e.name == name, orElse: () => OrderStatus.pending);
}
