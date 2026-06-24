import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../backend/models/customer.dart';
import '../../../constants/app_constants.dart';
import '../../../domain/state/measurement_state.dart';
import '../../../domain/state/order_state.dart';
import '../../../domain/services/recordings/entity_recording.dart';

/// Shared behaviour for a customer's voice-note rows — used by both the preview
/// card and the full "View all" screen so navigation and labels stay identical.
class CustomerRecordingActions {
  CustomerRecordingActions._();

  /// "Today" / "Yesterday" / "MMM d, y".
  static String dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d, y').format(d);
  }

  /// Open the order/measurement a recording belongs to. No-op if the source
  /// row can no longer be found in state.
  static void openSource(
    BuildContext context,
    EntityRecording rec,
    Customer customer,
    OrderState orderState,
    MeasurementState measurementState,
  ) {
    switch (rec.kind) {
      case EntityRecordingKind.order:
        final order = _firstWhereOrNull(orderState.orders, rec.entityId);
        if (order == null) return;
        Navigator.pushNamed(
          context,
          AppConstants.orderDetailRoute,
          arguments: {'order': order, 'customer': customer},
        );
      case EntityRecordingKind.measurement:
        final measurement = _firstWhereOrNull(
          measurementState.getMeasurementsByCustomerId(customer.id),
          rec.entityId,
        );
        if (measurement == null) return;
        Navigator.pushNamed(
          context,
          AppConstants.measurementDetailRoute,
          arguments: {'measurement': measurement, 'customer': customer},
        );
    }
  }

  static T? _firstWhereOrNull<T>(List<T> items, String id) {
    for (final item in items) {
      if ((item as dynamic).id == id) return item;
    }
    return null;
  }
}
