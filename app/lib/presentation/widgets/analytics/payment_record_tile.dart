import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_config.dart';
import '../../../domain/models/analytics.dart';

/// One payment row inside the month detail list. Shows who paid, for which
/// order, when, and how much. Tap → navigate to the parent order.
class PaymentRecordTile extends StatelessWidget {
  final PaymentRecord record;
  final VoidCallback onTap;

  const PaymentRecordTile({
    super.key,
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final order = record.order;
    final dateLabel = DateFormat('MMM d, y').format(record.payment.date);
    final orderLabel = (order.title?.trim().isNotEmpty ?? false)
        ? order.title!
        : 'Order #${order.id.substring(0, order.id.length.clamp(0, AppConfig.orderIdPreviewLength))}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.customerName,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConfig.spacing4),
                  Text(
                    orderLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConfig.spacing4),
                  Text(
                    dateLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConfig.spacing12),
            Text(
              '₹${record.payment.amount}',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppConfig.spacing4),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
