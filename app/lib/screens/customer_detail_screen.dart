import 'package:flutter/material.dart';

import '../backend/backend.dart';
import '../presentation/presentation.dart';

/// Full-screen customer detail (phone, and any push from the route). Thin
/// wrapper around the reusable [CustomerDetailView], which also powers the
/// tablet master–detail pane.
class CustomerDetailScreen extends StatelessWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomerDetailView(
        customer: customer,
        leading: const BackButton(),
        onDeleted: () => Navigator.of(context).pop(),
      ),
    );
  }
}
