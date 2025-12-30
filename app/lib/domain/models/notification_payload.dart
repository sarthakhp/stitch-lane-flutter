enum NotificationPayload {
  pendingOrdersReminder('pending_orders_reminder');

  final String value;
  const NotificationPayload(this.value);

  static NotificationPayload? fromString(String? value) {
    if (value == null) return null;
    for (final payload in NotificationPayload.values) {
      if (payload.value == value) return payload;
    }
    return null;
  }
}

