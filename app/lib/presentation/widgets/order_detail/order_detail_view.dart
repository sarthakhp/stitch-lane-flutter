import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/backend.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../confirmation_dialog.dart';
import '../detail/detail_header.dart';
import 'order_detail_action_bar.dart';
import 'order_detail_body.dart';

/// Self-contained order detail: a header (edit/delete), the scrollable body,
/// and the bottom action bar. Live-resolves the order/customer from state so it
/// reflects edits and payments instantly. Owns all order mutations.
///
/// Used full-screen (with a back button as [leading]) and as the right pane of
/// the tablet master–detail orders screen ([leading] null, [onDeleted] clears
/// the selection).
class OrderDetailView extends StatefulWidget {
  /// Initial order/customer; the live versions are resolved from state by id,
  /// falling back to these (e.g. before state has loaded).
  final Order order;
  final Customer customer;

  final Widget? leading;
  final VoidCallback? onDeleted;
  final bool showViewCustomer;

  const OrderDetailView({
    super.key,
    required this.order,
    required this.customer,
    this.leading,
    this.onDeleted,
    this.showViewCustomer = true,
  });

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  late String _orderId;
  late String _customerId;

  @override
  void initState() {
    super.initState();
    _orderId = widget.order.id;
    _customerId = widget.customer.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeasurements());
  }

  @override
  void didUpdateWidget(covariant OrderDetailView old) {
    super.didUpdateWidget(old);
    // The tablet pane reuses one view instance across selections — reload
    // measurements when the shown order/customer changes.
    if (widget.order.id != _orderId || widget.customer.id != _customerId) {
      _orderId = widget.order.id;
      _customerId = widget.customer.id;
      _loadMeasurements();
    }
  }

  Future<void> _loadMeasurements() async {
    await MeasurementService.loadMeasurementsByCustomerId(
      context.read<MeasurementState>(),
      context.read<MeasurementRepository>(),
      _customerId,
    );
  }

  Future<void> _updateOrder(Order updated) async {
    try {
      await OrderService.updateOrder(
        context.read<OrderState>(),
        context.read<OrderRepository>(),
        updated,
      );
    } catch (e) {
      _snack('Failed to update order: $e');
    }
  }

  Future<void> _toggleStatus(Order order) async {
    try {
      await OrderService.toggleOrderStatus(
        context.read<OrderState>(),
        context.read<OrderRepository>(),
        order,
      );
    } catch (e) {
      _snack('Failed to update order status: $e');
    }
  }

  void _editOrder(Order order, Customer customer) {
    Navigator.pushNamed(
      context,
      AppConstants.orderFormRoute,
      arguments: {'order': order, 'customer': customer},
    );
  }

  Future<void> _deleteOrder() async {
    final confirmed = await ConfirmationDialog.showDouble(
      context: context,
      title: 'Delete Order',
      content: 'Are you sure you want to delete this order? '
          'This cannot be undone.',
      secondTitle: 'Delete for good?',
      secondContent: 'This will permanently delete the order and its payment '
          'history. Tap Delete to confirm.',
    );
    if (!confirmed || !mounted) return;

    try {
      await OrderService.deleteOrder(
        context.read<OrderState>(),
        context.read<OrderRepository>(),
        _orderId,
      );
      if (!mounted) return;
      widget.onDeleted?.call();
      _snack('Order deleted successfully');
    } catch (e) {
      _snack('Failed to delete order: $e');
    }
  }

  void _viewCustomer(Customer customer) {
    Navigator.pushNamed(
      context,
      AppConstants.customerDetailRoute,
      arguments: customer,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrderState, CustomerState>(
      builder: (context, orderState, customerState, _) {
        final order = orderState.orders.firstWhere(
          (o) => o.id == _orderId,
          orElse: () => widget.order,
        );
        final customer = customerState.customers.firstWhere(
          (c) => c.id == _customerId,
          orElse: () => widget.customer,
        );

        return Column(
          children: [
            DetailHeader(
              title: "${customer.name}'s Order",
              leading: widget.leading,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () => _editOrder(order, customer),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: _deleteOrder,
                ),
              ],
            ),
            Expanded(
              child: OrderDetailBody(
                order: order,
                customer: customer,
                onOrderUpdated: _updateOrder,
              ),
            ),
            OrderDetailActionBar(
              order: order,
              customerName: customer.name,
              onToggleStatus: () => _toggleStatus(order),
              onViewCustomer:
                  widget.showViewCustomer ? () => _viewCustomer(customer) : null,
            ),
          ],
        );
      },
    );
  }
}
