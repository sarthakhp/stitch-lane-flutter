import 'package:flutter/material.dart';
import '../../backend/models/customer.dart';
import '../../config/app_config.dart';

class CustomerListItem extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final int pendingOrderCount;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.onTap,
    this.pendingOrderCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasNoPendingOrders = pendingOrderCount == 0;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing8,
        ),
        leading: CircleAvatar(
          backgroundColor: hasNoPendingOrders
              ? Colors.green.shade100
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            hasNoPendingOrders ? Icons.check_circle : Icons.person,
            color: hasNoPendingOrders
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          customer.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: _buildSubtitle(context),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final phoneText = customer.phoneNumber ?? 'No phone number';
    final phoneStyle = customer.phoneNumber != null
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );

    final bool hasNoPendingOrders = pendingOrderCount == 0;
    final pendingText = hasNoPendingOrders ? 'All done' : '$pendingOrderCount pending';
    final pendingColor = hasNoPendingOrders
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          phoneText,
          style: phoneStyle,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          pendingText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: pendingColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

