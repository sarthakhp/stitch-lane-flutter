import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../../../domain/state/sync_state.dart';
import '../contact_action_buttons.dart';

/// Bottom action area of a customer's detail, top to bottom: contact buttons
/// (when a phone number exists), Create Order (writer only), then View Orders
/// (with a count badge).
class CustomerDetailActionBar extends StatelessWidget {
  final Customer customer;

  const CustomerDetailActionBar({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty;
    final canWrite = context.select<SyncState, bool>((s) => s.canWrite);

    // Built in display order; only present items get gaps between them, so a
    // hidden Create Order (reader) or missing phone never leaves a blank space.
    final actions = <Widget>[
      if (hasPhone) ContactActionButtons(phoneNumber: customer.phoneNumber!),
      if (canWrite)
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            AppConstants.orderCreatorRoute,
            arguments: {'customer': customer},
          ),
          icon: const Icon(Icons.add),
          label: const Text('Create Order'),
        ),
      _buildViewOrders(context),
    ];

    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: AppConfig.spacing4),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewOrders(BuildContext context) {
    return Consumer<OrderState>(
      builder: (context, orderState, _) {
        final orderCount =
            orderState.orders.where((o) => o.customerId == customer.id).length;
        return FilledButton.icon(
          onPressed: () => Navigator.pushNamed(
            context,
            AppConstants.ordersListRoute,
            arguments: customer,
          ),
          icon: Badge(
            label: Text('$orderCount'),
            isLabelVisible: orderCount > 0,
            child: const Icon(Icons.assignment),
          ),
          label: const Text('View Orders'),
        );
      },
    );
  }
}
