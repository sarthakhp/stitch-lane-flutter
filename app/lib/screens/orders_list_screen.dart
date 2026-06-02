import 'package:flutter/material.dart';

import '../backend/backend.dart';
import '../constants/app_constants.dart';
import '../domain/models/filter_preset.dart';
import '../presentation/presentation.dart';

/// Route target for a customer's orders and the all-orders list. A thin wrapper
/// over the shared [OrdersBrowser]; it only supplies scope, title, and the
/// create action (this route shows a sticky button rather than the shell FAB).
class OrdersListScreen extends StatelessWidget {
  final Customer? customer;
  final FilterPreset? initialFilterPreset;

  const OrdersListScreen({
    super.key,
    this.customer,
    this.initialFilterPreset,
  });

  @override
  Widget build(BuildContext context) {
    return OrdersBrowser(
      customer: customer,
      title: customer != null ? "${customer!.name}'s Orders" : 'All Orders',
      initialPreset: initialFilterPreset,
      onCreate: () => Navigator.pushNamed(
        context,
        AppConstants.orderCreatorRoute,
        arguments: customer != null
            ? <String, dynamic>{'customer': customer}
            : <String, dynamic>{},
      ),
    );
  }
}
