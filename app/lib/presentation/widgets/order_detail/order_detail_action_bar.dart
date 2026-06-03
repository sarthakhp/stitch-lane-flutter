import 'package:flutter/material.dart';

import '../../../backend/models/order.dart';
import '../../../config/app_config.dart';
import 'order_status_presentation.dart';

/// Bottom action area of an order's detail: cycle status, a (read-only) paid
/// indicator, and an optional "view customer" button. The status color/icon/
/// text come from [order_status_presentation].
class OrderDetailActionBar extends StatelessWidget {
  final Order order;
  final VoidCallback onToggleStatus;

  /// Customer name, used to personalise the view-profile button label. Falls
  /// back to a generic label when null/empty.
  final String? customerName;

  /// When null the "View customer" button is hidden (e.g. already inside that
  /// customer's orders list on tablet).
  final VoidCallback? onViewCustomer;

  const OrderDetailActionBar({
    super.key,
    required this.order,
    required this.onToggleStatus,
    this.customerName,
    this.onViewCustomer,
  });

  /// "View <name>'s Profile" when a name is known, else a generic fallback.
  String get _viewLabel {
    final name = customerName?.trim() ?? '';
    return name.isEmpty ? 'View Customer' : "View $name's Profile";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = orderStatusColor(context, order.status);

    return Container(
      padding: const EdgeInsets.all(AppConfig.spacing16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onToggleStatus,
                    icon: Icon(orderStatusIcon(order.status)),
                    label: Text(orderStatusText(order.status)),
                    style: FilledButton.styleFrom(
                      backgroundColor: statusColor.withValues(alpha: 0.2),
                      foregroundColor: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppConfig.spacing8),
                Expanded(child: _buildPaidIndicator(context, colorScheme)),
              ],
            ),
            if (onViewCustomer != null) ...[
              const SizedBox(height: AppConfig.spacing8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onViewCustomer,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: AppConfig.spacing8),
                      // Flexible so long customer names ellipsize instead of
                      // overflowing the full-width button.
                      Flexible(
                        child: Text(
                          _viewLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaidIndicator(BuildContext context, ColorScheme colorScheme) {
    final accent = order.isPaid ? colorScheme.primary : colorScheme.error;
    return FilledButton.tonalIcon(
      onPressed: null,
      icon: Icon(order.isPaid ? Icons.check_circle : Icons.pending),
      label: Text(order.isPaid ? 'Paid' : 'Not Paid'),
      style: FilledButton.styleFrom(
        backgroundColor: accent.withValues(alpha: 0.2),
        foregroundColor: accent,
        disabledBackgroundColor: accent.withValues(alpha: 0.2),
        disabledForegroundColor: accent,
      ),
    );
  }
}
