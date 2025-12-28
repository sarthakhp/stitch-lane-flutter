class CustomerPendingInfo {
  final String customerId;
  final String customerName;
  final int pendingOrderCount;
  final int readyOrderCount;
  final DateTime nearestDueDate;

  CustomerPendingInfo({
    required this.customerId,
    required this.customerName,
    required this.pendingOrderCount,
    required this.readyOrderCount,
    required this.nearestDueDate,
  });
}

class PendingOrdersData {
  final List<CustomerPendingInfo> customers;
  final int totalPendingOrders;

  PendingOrdersData({
    required this.customers,
    required this.totalPendingOrders,
  });

  bool get hasOrders => customers.isNotEmpty;

  int get customerCount => customers.length;
}

