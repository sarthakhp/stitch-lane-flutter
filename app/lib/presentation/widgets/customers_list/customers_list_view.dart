import 'package:flutter/material.dart';

import '../../../backend/models/customer.dart';
import '../../../backend/models/order.dart';
import '../customer_list_item.dart';

/// Per-customer order counts the list row needs (from OrderState), supplied by
/// the host so this widget stays presentational.
typedef CustomerStats = ({int pending, int ready, int unpaid});

/// Selection-aware list of customers. Mirrors OrdersListView: the host supplies
/// the already filtered/sorted [customers], a [statsFor] resolver, and decides
/// what a tap means (navigate on phone, select on tablet).
class CustomersListView extends StatelessWidget {
  final List<Customer> customers;
  final List<Order> allOrders;

  /// Currently selected customer (tablet); null on phone.
  final String? selectedCustomerId;
  final int dueDateWarningThreshold;
  final CustomerStats Function(String customerId) statsFor;

  final void Function(Customer customer) onSelect;
  final Future<void> Function() onRefresh;

  const CustomersListView({
    super.key,
    required this.customers,
    required this.allOrders,
    required this.selectedCustomerId,
    required this.dueDateWarningThreshold,
    required this.statsFor,
    required this.onSelect,
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
          itemCount: customers.length,
          itemBuilder: (context, index) {
            final customer = customers[index];
            final stats = statsFor(customer.id);
            return CustomerListItem(
              customer: customer,
              selected: customer.id == selectedCustomerId,
              pendingOrderCount: stats.pending,
              readyOrderCount: stats.ready,
              totalUnpaidAmount: stats.unpaid,
              allOrders: allOrders,
              dueDateWarningThreshold: dueDateWarningThreshold,
              onTap: () => onSelect(customer),
            );
          },
        ),
      ),
    );
  }
}
