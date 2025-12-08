import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';
import '../../config/app_config.dart';

class OrderListItem extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final String? customerName;
  final int dueDateWarningThreshold;

  const OrderListItem({
    super.key,
    required this.order,
    required this.onTap,
    this.customerName,
    required this.dueDateWarningThreshold,
  });

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  String? _getDescriptionPreview() {
    if (order.description != null && order.description!.isNotEmpty) {
      return order.description!.length > 50
          ? '${order.description!.substring(0, 50)}...'
          : order.description!;
    }
    return null;
  }

  bool _isDueSoon() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(order.dueDate.year, order.dueDate.month, order.dueDate.day);
    final difference = dueDate.difference(today).inDays;
    return difference <= dueDateWarningThreshold && difference >= 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDueSoon = _isDueSoon();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      shape: isDueSoon
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
              side: BorderSide(
                color: colorScheme.error,
                width: 2.0,
              ),
            )
          : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing8,
        ),
        leading: CircleAvatar(
          backgroundColor: order.status == OrderStatus.done
              ? Colors.green.shade100
              : Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            order.status == OrderStatus.done
                ? Icons.check_circle
                : Icons.assignment,
            color: order.status == OrderStatus.done
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          order.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Due: ${_formatDate(order.dueDate)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDueSoon ? colorScheme.error : null,
                fontWeight: isDueSoon ? FontWeight.w600 : null,
              ),
            ),
            if (customerName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Customer: $customerName',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (_getDescriptionPreview() != null) ...[
              const SizedBox(height: 4),
              Text(
                _getDescriptionPreview()!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

