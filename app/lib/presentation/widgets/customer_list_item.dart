import 'package:flutter/material.dart';
import '../../backend/models/customer.dart';
import '../../config/app_config.dart';

class CustomerListItem extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final int pendingOrderCount;
  final int readyOrderCount;
  final int totalUnpaidAmount;

  const CustomerListItem({
    super.key,
    required this.customer,
    required this.onTap,
    this.pendingOrderCount = 0,
    this.readyOrderCount = 0,
    this.totalUnpaidAmount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasNoPendingOrders = pendingOrderCount == 0;
    final bool hasNoReadyOrders = readyOrderCount == 0;
    final bool allOrdersDone = hasNoPendingOrders && hasNoReadyOrders;
    final bool hasUnpaidAmount = totalUnpaidAmount > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: allOrdersDone
                    ? Colors.green.shade100
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  allOrdersDone ? Icons.check_circle : Icons.person,
                  color: allOrdersDone
                      ? Colors.green.shade700
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppConfig.spacing4),
                    _buildSubtitle(context),
                  ],
                ),
              ),
              const SizedBox(width: AppConfig.spacing16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹$totalUnpaidAmount',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: hasUnpaidAmount
                          ? colorScheme.error
                          : colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConfig.spacing4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConfig.spacing8,
                      vertical: AppConfig.spacing4,
                    ),
                    decoration: BoxDecoration(
                      color: hasUnpaidAmount
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppConfig.spacing12),
                    ),
                    child: Text(
                      hasUnpaidAmount ? 'Unpaid' : 'All Paid',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: hasUnpaidAmount
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    final bool hasNoReadyOrders = readyOrderCount == 0;
    final bool allOrdersDone = hasNoPendingOrders && hasNoReadyOrders;

    String statusText;
    Color statusColor;

    if (allOrdersDone) {
      statusText = 'All done';
      statusColor = Colors.green.shade700;
    } else {
      final List<String> statusParts = [];
      if (!hasNoPendingOrders) {
        statusParts.add('$pendingOrderCount pending');
      }
      if (!hasNoReadyOrders) {
        statusParts.add('$readyOrderCount ready');
      }
      statusText = statusParts.join(', ');
      statusColor = Theme.of(context).colorScheme.primary;
    }

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
          statusText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

