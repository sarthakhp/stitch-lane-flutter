import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../backend/backend.dart';
import '../../domain/domain.dart';

class OrderStatusToggle extends StatelessWidget {
  final Order order;

  const OrderStatusToggle({
    super.key,
    required this.order,
  });

  Future<void> _toggleOrderStatus(BuildContext context) async {
    final state = context.read<OrderState>();
    final repository = context.read<OrderRepository>();

    try {
      final OrderStatus newStatus;
      final String statusMessage;

      switch (order.status) {
        case OrderStatus.pending:
          newStatus = OrderStatus.ready;
          statusMessage = 'Order marked as ready';
          break;
        case OrderStatus.ready:
          newStatus = OrderStatus.done;
          statusMessage = 'Order marked as done';
          break;
        case OrderStatus.done:
          newStatus = OrderStatus.pending;
          statusMessage = 'Order marked as pending';
          break;
      }

      final updatedOrder = order.copyWith(status: newStatus);

      await OrderService.updateOrder(state, repository, updatedOrder);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(statusMessage),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update order status: $e')),
        );
      }
    }
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.done:
        return 'Done';
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.ready:
        return Icons.schedule;
      case OrderStatus.done:
        return Icons.check_circle;
    }
  }

  Color _getStatusColor(BuildContext context, OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Theme.of(context).colorScheme.error;
      case OrderStatus.ready:
        return Colors.orange;
      case OrderStatus.done:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('Order Status'),
        subtitle: Text(
          _getStatusText(order.status),
          style: TextStyle(
            color: _getStatusColor(context, order.status),
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Icon(
          _getStatusIcon(order.status),
          color: _getStatusColor(context, order.status),
        ),
        trailing: const Icon(Icons.touch_app),
        onTap: () => _toggleOrderStatus(context),
      ),
    );
  }
}

