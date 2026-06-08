import 'package:flutter/material.dart';
import '../../../backend/models/order.dart';
import '../../../backend/models/order_status.dart';
import '../../../config/app_config.dart';

/// Dashboard pane that surfaces what needs doing: orders not yet collected,
/// either overdue or due within the next few days, soonest first. Fills the
/// tablet's spare space with at-a-glance work instead of a navigation void.
class NeedsAttentionPanel extends StatelessWidget {
  final List<Order> orders;
  final String Function(String customerId) customerName;
  final void Function(Order order) onTapOrder;

  /// Look-ahead window — orders due within this many days (plus anything
  /// overdue) show up here.
  final int withinDays;

  const NeedsAttentionPanel({
    super.key,
    required this.orders,
    required this.customerName,
    required this.onTapOrder,
    this.withinDays = 3,
  });

  List<Order> _dueSoon() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.add(Duration(days: withinDays));

    final result = orders.where((o) {
      if (o.status == OrderStatus.done) return false;
      final due = DateTime(o.dueDate.year, o.dueDate.month, o.dueDate.day);
      return !due.isAfter(cutoff);
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = _dueSoon();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConfig.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: colorScheme.primary),
                const SizedBox(width: AppConfig.spacing8),
                Text(
                  'Needs attention',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppConfig.spacing12),
            if (items.isEmpty)
              SizedBox(width: double.infinity, child: _EmptyState(theme: theme))
            else
              ...items.map((order) => _DueOrderRow(
                    order: order,
                    customerName: customerName(order.customerId),
                    onTap: () => onTapOrder(order),
                  )),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing24),
      // Full width so the centered content sits in the middle of the panel
      // (the parent Column is crossAxisAlignment.start).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: AppConfig.spacing8),
          Text(
            'All caught up',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppConfig.spacing4),
          Text(
            'Nothing due in the next few days.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DueOrderRow extends StatelessWidget {
  final Order order;
  final String customerName;
  final VoidCallback onTap;

  const _DueOrderRow({
    required this.order,
    required this.customerName,
    required this.onTap,
  });

  ({String text, bool overdue}) _dueLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(order.dueDate.year, order.dueDate.month, order.dueDate.day);
    final days = due.difference(today).inDays;
    if (days < 0) return (text: 'Overdue', overdue: true);
    if (days == 0) return (text: 'Due today', overdue: true);
    if (days == 1) return (text: 'Due tomorrow', overdue: false);
    return (text: 'Due in $days days', overdue: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final due = _dueLabel();
    final dueColor = due.overdue ? colorScheme.error : colorScheme.primary;
    final title = (order.title != null && order.title!.isNotEmpty)
        ? order.title!
        : 'Order';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConfig.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConfig.spacing12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConfig.spacing12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConfig.spacing8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: dueColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    due.text,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: dueColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (order.outstanding > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '₹${order.outstanding} due',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
