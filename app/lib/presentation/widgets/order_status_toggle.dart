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
      final newStatus = order.status == OrderStatus.done
          ? OrderStatus.pending
          : OrderStatus.done;

      final updatedOrder = order.copyWith(status: newStatus);

      await OrderService.updateOrder(state, repository, updatedOrder);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 800),
            content: Text(
              newStatus == OrderStatus.done
                  ? 'Order marked as done'
                  : 'Order marked as pending',
            ),
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

  @override
  Widget build(BuildContext context) {
    final isDone = order.status == OrderStatus.done;

    return Card(
      child: SwitchListTile(
        title: const Text('Order Status'),
        subtitle: Text(
          isDone ? 'Done' : 'Pending',
          style: TextStyle(
            color: isDone
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
        value: isDone,
        onChanged: (value) => _toggleOrderStatus(context),
        secondary: Icon(
          isDone ? Icons.check_circle : Icons.pending,
          color: isDone
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

