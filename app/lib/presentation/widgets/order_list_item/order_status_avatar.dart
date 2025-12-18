import 'package:flutter/material.dart';
import '../../../backend/models/order_status.dart';

class OrderStatusAvatar extends StatelessWidget {
  final OrderStatus status;

  const OrderStatusAvatar({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = status == OrderStatus.done;
    
    return CircleAvatar(
      backgroundColor: isDone
          ? Colors.green.shade100
          : Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        isDone ? Icons.check_circle : Icons.assignment,
        color: isDone
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}

