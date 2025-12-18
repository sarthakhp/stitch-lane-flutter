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
  final String? customerName;
  final int dueDateWarningThreshold;

  const OrderListItem({
    super.key,
    required this.order,
    required this.onTap,
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConfig.spacing16,
          vertical: AppConfig.spacing8,
        ),
        leading: OrderStatusAvatar(status: order.status),
        title: OrderTitleText(
          order: order,
          customerName: customerName,
        ),
        subtitle: OrderSubtitle(
          order: order,
          customerName: customerName,
          isDueSoon: isDueSoon,
        ),
        onTap: onTap,
      ),
    );
  }
}

