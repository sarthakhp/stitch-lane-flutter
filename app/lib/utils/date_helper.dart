import '../backend/models/order.dart';
import '../backend/models/order_status.dart';

class DateHelper {
  static bool isDueSoon(
    Order order,
    int dueDateWarningThreshold,
  ) {
    if (order.status == OrderStatus.done || order.status == OrderStatus.ready) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      order.dueDate.year,
      order.dueDate.month,
      order.dueDate.day,
    );
    final difference = dueDate.difference(today).inDays;

    return difference <= dueDateWarningThreshold;
  }

  static bool hasCustomerPendingOrdersDueSoon(
    String customerId,
    List<Order> orders,
    int dueDateWarningThreshold,
  ) {
    final customerOrders = orders.where((order) => order.customerId == customerId);

    return customerOrders.any((order) => isDueSoon(order, dueDateWarningThreshold));
  }
}

