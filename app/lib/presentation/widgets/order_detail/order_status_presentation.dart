import 'package:flutter/material.dart';

import '../../../backend/models/order_status.dart';

/// Presentation helpers for an [OrderStatus] — shared by the detail action bar
/// and anywhere else that renders a status. Pure mapping, no widgets.

String orderStatusText(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 'Pending';
    case OrderStatus.ready:
      return 'Ready';
    case OrderStatus.done:
      return 'Done';
  }
}

IconData orderStatusIcon(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Icons.access_time_outlined;
    case OrderStatus.ready:
      return Icons.check;
    case OrderStatus.done:
      return Icons.done_all;
  }
}

Color orderStatusColor(BuildContext context, OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return Theme.of(context).colorScheme.onSecondaryContainer;
    case OrderStatus.ready:
      return Colors.orange.shade700;
    case OrderStatus.done:
      return Colors.green.shade700;
  }
}
