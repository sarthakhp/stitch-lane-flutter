import 'package:flutter/material.dart';

import '../../../backend/models/customer.dart';
import '../../../backend/models/order.dart';
import '../order_list_item.dart';

/// Selection-aware list of orders. Presentational: the host supplies the
/// already filtered/sorted [orders], resolves each order's customer, and
/// decides what a tap means (navigate on phone, select on tablet).
class OrdersListView extends StatelessWidget {
  final List<Order> orders;
  final Customer? Function(Order order) resolveCustomer;

  /// Currently selected order (tablet); null on phone.
  final String? selectedOrderId;

  /// Show the customer name on each row (true for the all-orders list).
  final bool showCustomerName;
  final int dueDateWarningThreshold;

  final void Function(Order order, Customer customer) onSelect;
  final void Function(Order order) onToggleStatus;
  final Future<void> Function() onRefresh;

  const OrdersListView({
    super.key,
    required this.orders,
    required this.resolveCustomer,
    required this.selectedOrderId,
    required this.showCustomerName,
    required this.dueDateWarningThreshold,
    required this.onSelect,
    required this.onToggleStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) FocusScope.of(context).unfocus();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final customer = resolveCustomer(order);
            if (customer == null) return const SizedBox.shrink();
            return OrderListItem(
              order: order,
              customerName: showCustomerName ? customer.name : null,
              selected: order.id == selectedOrderId,
              dueDateWarningThreshold: dueDateWarningThreshold,
              onTap: () => onSelect(order, customer),
              onStatusToggle: () => onToggleStatus(order),
            );
          },
        ),
      ),
    );
  }
}
