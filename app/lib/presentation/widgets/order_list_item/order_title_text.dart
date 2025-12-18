import 'package:flutter/material.dart';
import '../../../backend/models/order.dart';

class OrderTitleText extends StatelessWidget {
  final Order order;
  final String? customerName;

  const OrderTitleText({
    super.key,
    required this.order,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );

    if (customerName != null) {
      return Text(customerName!, style: titleStyle);
    }

    return const SizedBox.shrink();
  }
}

