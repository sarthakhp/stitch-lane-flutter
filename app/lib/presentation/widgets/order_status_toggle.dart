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
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<OrderStatus>(
        segments: const [
          ButtonSegment<OrderStatus>(
            value: OrderStatus.pending,
            label: Text('Pending'),
            icon: Icon(Icons.pending_outlined),
          ),
          ButtonSegment<OrderStatus>(
            value: OrderStatus.done,
            label: Text('Done'),
            icon: Icon(Icons.check_circle_outline),
          ),
        ],
        selected: {order.status},
        onSelectionChanged: (Set<OrderStatus> newSelection) {
          _toggleOrderStatus(context);
        },
        style: const ButtonStyle(
          visualDensity: VisualDensity.comfortable,
        ),
      ),
    );
  }
}

