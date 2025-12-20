import '../../backend/models/customer.dart';
import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';

class CustomerFilterOptions {
  final bool showPending;
  final bool showReady;
  final bool showDone;
  final bool showPaid;
  final bool showNotPaid;

  const CustomerFilterOptions({
    this.showPending = true,
    this.showReady = true,
    this.showDone = true,
    this.showPaid = true,
    this.showNotPaid = true,
  });

  const CustomerFilterOptions.doneButNotPaid()
      : showPending = false,
        showReady = false,
        showDone = true,
        showPaid = false,
        showNotPaid = true;

  const CustomerFilterOptions.pending()
      : showPending = true,
        showReady = false,
        showDone = false,
        showPaid = true,
        showNotPaid = true;

  const CustomerFilterOptions.ready()
      : showPending = false,
        showReady = true,
        showDone = false,
        showPaid = true,
        showNotPaid = true;

  CustomerFilterOptions copyWith({
    bool? showPending,
    bool? showReady,
    bool? showDone,
    bool? showPaid,
    bool? showNotPaid,
  }) {
    return CustomerFilterOptions(
      showPending: showPending ?? this.showPending,
      showReady: showReady ?? this.showReady,
      showDone: showDone ?? this.showDone,
      showPaid: showPaid ?? this.showPaid,
      showNotPaid: showNotPaid ?? this.showNotPaid,
    );
  }

  bool get isFilterActive {
    return !showPending ||
        !showReady ||
        !showDone ||
        !showPaid ||
        !showNotPaid;
  }

  bool get hasNoStatusSelected {
    return !showPending && !showReady && !showDone;
  }

  bool get hasNoPaymentSelected {
    return !showPaid && !showNotPaid;
  }

  bool matchesCustomer(Customer customer, List<Order> allOrders) {
    final customerOrders = allOrders.where((o) => o.customerId == customer.id).toList();
    
    if (customerOrders.isEmpty) {
      return false;
    }

    final hasPendingOrders = customerOrders.any((o) => o.status == OrderStatus.pending);
    final hasReadyOrders = customerOrders.any((o) => o.status == OrderStatus.ready);
    final hasDoneOrders = customerOrders.any((o) => o.status == OrderStatus.done);
    final hasPaidOrders = customerOrders.any((o) => o.isPaid);
    final hasUnpaidOrders = customerOrders.any((o) => !o.isPaid);

    final statusMatch = hasNoStatusSelected ||
        (hasPendingOrders && showPending) ||
        (hasReadyOrders && showReady) ||
        (hasDoneOrders && showDone);

    final paymentMatch = hasNoPaymentSelected ||
        (hasPaidOrders && showPaid) ||
        (hasUnpaidOrders && showNotPaid);

    return statusMatch && paymentMatch;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerFilterOptions &&
        other.showPending == showPending &&
        other.showReady == showReady &&
        other.showDone == showDone &&
        other.showPaid == showPaid &&
        other.showNotPaid == showNotPaid;
  }

  @override
  int get hashCode {
    return Object.hash(
      showPending,
      showReady,
      showDone,
      showPaid,
      showNotPaid,
    );
  }

  @override
  String toString() {
    return 'CustomerFilterOptions(showPending: $showPending, showReady: $showReady, showDone: $showDone, showPaid: $showPaid, showNotPaid: $showNotPaid)';
  }
}

