import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../backend/models/customer.dart';
import '../../../config/app_config.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/domain.dart';
import '../contact_action_buttons.dart';

/// Bottom action area of a customer's detail: View Orders (with a count badge),
/// Create Order, and contact buttons when a phone number exists.
class CustomerDetailActionBar extends StatelessWidget {
  final Customer customer;

  const CustomerDetailActionBar({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final hasPhone =
        customer.phoneNumber != null && customer.phoneNumber!.isNotEmpty;

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
            Consumer<OrderState>(
              builder: (context, orderState, _) {
                final orderCount = orderState.orders
                    .where((o) => o.customerId == customer.id)
                    .length;
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
            ),
            const SizedBox(height: AppConfig.spacing8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                AppConstants.orderCreatorRoute,
                arguments: {'customer': customer},
              ),
              icon: const Icon(Icons.add),
              label: const Text('Create Order'),
            ),
            if (hasPhone) ...[
              const SizedBox(height: AppConfig.spacing8),
              ContactActionButtons(phoneNumber: customer.phoneNumber!),
            ],
          ],
        ),
      ),
    );
  }
}
