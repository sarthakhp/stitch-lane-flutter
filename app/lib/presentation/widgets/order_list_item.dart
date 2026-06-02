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

  /// Highlights the row as the active selection in the tablet master–detail
  /// layout. No effect on phones (where tapping navigates instead).
  final bool selected;

  const OrderListItem({
    super.key,
    required this.order,
    required this.onTap,
    required this.onStatusToggle,
    this.customerName,
    required this.dueDateWarningThreshold,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDueSoon = DateHelper.isDueSoon(order, dueDateWarningThreshold);
    final colorScheme = Theme.of(context).colorScheme;

    // Selection takes visual priority over the due-soon outline.
    final BorderSide? side = selected
        ? BorderSide(color: colorScheme.primary, width: 2.0)
        : (isDueSoon ? BorderSide(color: colorScheme.error, width: 2.0) : null);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConfig.spacing16,
        vertical: AppConfig.spacing8,
      ),
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      shape: side != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
              side: side,
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
              // Sized to its content (no Flexible) so the Expanded title above
              // eats all the slack and the amount sits flush to the right edge.
              // A Flexible here reserved half the free width and left the unused
              // part as a gap on the right — very visible on wide tablets.
              _buildPaymentInfo(context, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentInfo(BuildContext context, ColorScheme colorScheme) {
    // No price decided yet — show a neutral "Price not set" instead of a
    // misleading ₹0 / Not Paid.
    if (order.value == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Price not set',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final displayAmount =
        order.isPaid ? order.totalPaidAmount : order.outstanding;

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
          overflow: TextOverflow.ellipsis,
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

