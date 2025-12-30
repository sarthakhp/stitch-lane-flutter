import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer_filter_preset.dart';
import '../models/notification_payload.dart';
import '../state/main_shell_state.dart';
import 'notification_service.dart';

class NotificationRouter {
  static void processPendingNotification(BuildContext context) {
    final payload = NotificationService.consumePendingPayload();
    if (payload == null) return;

    switch (payload) {
      case NotificationPayload.pendingOrdersReminder:
        _navigateToPendingCustomers(context);
    }
  }

  static void _navigateToPendingCustomers(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<MainShellState>().switchToCustomersTab(
      filter: CustomerFilterPreset.pending(),
    );
  }
}

