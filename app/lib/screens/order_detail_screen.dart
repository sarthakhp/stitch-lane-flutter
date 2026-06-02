import 'package:flutter/material.dart';

import '../backend/backend.dart';
import '../presentation/presentation.dart';

/// Full-screen order detail (phone, and any push from the route). Thin wrapper
/// around the reusable [OrderDetailView], which also powers the tablet
/// master–detail pane.
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  final Customer customer;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrderDetailView(
        order: order,
        customer: customer,
        leading: const BackButton(),
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}
