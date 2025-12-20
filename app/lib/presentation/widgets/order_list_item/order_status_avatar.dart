import 'package:flutter/material.dart';
import '../../../backend/models/order_status.dart';

class OrderStatusAvatar extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusAvatar({
    super.key,
    required this.status,
  });

  Color _getBackgroundColor(BuildContext context) {
    switch (status) {
      case OrderStatus.pending:
        return Theme.of(context).colorScheme.secondaryContainer;
      case OrderStatus.ready:
        return Colors.orange.shade100;
      case OrderStatus.done:
        return Colors.green.shade100;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time_outlined;
      case OrderStatus.ready:
        return Icons.check;
      case OrderStatus.done:
        return Icons.done_all;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (status) {
      case OrderStatus.pending:
        return Theme.of(context).colorScheme.onSecondaryContainer;
      case OrderStatus.ready:
        return Colors.orange.shade700;
      case OrderStatus.done:
        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: _getBackgroundColor(context),
      child: Icon(
        _getIcon(),
        color: _getIconColor(context),
      ),
    );
  }
}

