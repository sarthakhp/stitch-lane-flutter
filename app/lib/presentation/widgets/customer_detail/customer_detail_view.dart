import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/backend.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../confirmation_dialog.dart';
import '../detail/detail_header.dart';
import 'customer_detail_action_bar.dart';
import 'customer_detail_body.dart';

/// Self-contained customer detail: header (edit/delete), scrollable body, and
/// the bottom action bar. Live-resolves the customer from state. Used both
/// full-screen (with a back button as [leading]) and as the tablet
/// master–detail right pane ([leading] null, [onDeleted] clears the selection).
class CustomerDetailView extends StatefulWidget {
  final Customer customer;
  final Widget? leading;
  final VoidCallback? onDeleted;

  const CustomerDetailView({
    super.key,
    required this.customer,
    this.leading,
    this.onDeleted,
  });

  @override
  State<CustomerDetailView> createState() => _CustomerDetailViewState();
}

class _CustomerDetailViewState extends State<CustomerDetailView> {
  late String _customerId;

  @override
  void initState() {
    super.initState();
    _customerId = widget.customer.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMeasurements());
  }

  @override
  void didUpdateWidget(covariant CustomerDetailView old) {
    super.didUpdateWidget(old);
    if (widget.customer.id != _customerId) {
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

  void _editCustomer(Customer customer) {
    Navigator.pushNamed(
      context,
      AppConstants.customerFormRoute,
      arguments: customer,
    );
  }

  Future<void> _deleteCustomer() async {
    final orderCount = context
        .read<OrderState>()
        .orders
        .where((o) => o.customerId == _customerId)
        .length;
    final orderLine = orderCount == 0
        ? 'all their measurements'
        : 'their $orderCount order${orderCount == 1 ? '' : 's'} and all measurements';

    final confirmed = await ConfirmationDialog.showDouble(
      context: context,
      title: 'Delete Customer',
      content:
          'This will permanently delete this customer along with $orderLine.\n\n'
          'This cannot be undone.',
      secondTitle: 'Delete for good?',
      secondContent:
          'Are you absolutely sure? The customer and $orderLine will be '
          'permanently removed. Tap Delete to confirm.',
    );
    if (!confirmed || !mounted) return;

    try {
      await CustomerService.deleteCustomer(
        context.read<CustomerState>(),
        context.read<CustomerRepository>(),
        _customerId,
        orderState: context.read<OrderState>(),
        orderRepository: context.read<OrderRepository>(),
      );
      if (!mounted) return;
      widget.onDeleted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete customer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerState>(
      builder: (context, customerState, _) {
        final customer = customerState.customers.firstWhere(
          (c) => c.id == _customerId,
          orElse: () => widget.customer,
        );

        return Column(
          children: [
            DetailHeader(
              title: customer.name,
              leading: widget.leading,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit',
                  onPressed: () => _editCustomer(customer),
                ),
              ],
            ),
            // Delete lives at the end of the body (rarely used), not the header.
            Expanded(
              child: CustomerDetailBody(
                customer: customer,
                onDelete: _deleteCustomer,
              ),
            ),
            CustomerDetailActionBar(customer: customer),
          ],
        );
      },
    );
  }
}
