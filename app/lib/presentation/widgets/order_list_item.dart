import 'package:flutter/material.dart';
import '../../backend/models/order.dart';
import '../../config/app_config.dart';
import '../../utils/date_helper.dart';
import 'order_list_item/order_status_avatar.dart';
import 'order_list_item/order_title_text.dart';
import 'order_list_item/order_subtitle.dart';

class OrderListItem extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final VoidCallback onStatusToggle;
  final String? customerName;
  final int dueDateWarningThreshold;

  const OrderListItem({
    super.key,
    required this.order,
    required this.onTap,
    required this.onStatusToggle,
    this.customerName,
    required this.dueDateWarningThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final isDueSoon = DateHelper.isDueSoon(order, dueDateWarningThreshold);
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppConfig.spacing16),
          child: Row(
            children: [
              InkWell(
                onTap: onStatusToggle,
                borderRadius: BorderRadius.circular(20),
                child: OrderStatusAvatar(status: order.status),
              ),
              const SizedBox(width: AppConfig.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OrderTitleText(
                      order: order,
                      customerName: customerName,
                    ),
                    const SizedBox(height: AppConfig.spacing4),
                    OrderSubtitle(
                      order: order,
                      customerName: customerName,
                      isDueSoon: isDueSoon,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConfig.spacing16),
              _buildPaymentInfo(context, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInfo(BuildContext context, ColorScheme colorScheme) {
    final remainingAmount = order.value - order.totalPaidAmount;
    final displayAmount = remainingAmount > 0 ? remainingAmount : 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₹$displayAmount',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: order.isPaid ? colorScheme.primary : colorScheme.error,
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
            color: order.isPaid
                ? colorScheme.primaryContainer
                : colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppConfig.spacing12),
          ),
          child: Text(
            order.isPaid ? 'Paid' : 'Not Paid',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: order.isPaid
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

