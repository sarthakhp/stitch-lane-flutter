import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';

class OrderFilterOptions {
  final bool showPending;
  final bool showReady;
  final bool showDone;
  final bool showPaid;
  final bool showNotPaid;

  const OrderFilterOptions({
    this.showPending = true,
    this.showReady = true,
    this.showDone = true,
    this.showPaid = true,
    this.showNotPaid = true,
  });

  const OrderFilterOptions.doneButNotPaid()
      : showPending = false,
        showReady = false,
        showDone = true,
        showPaid = false,
        showNotPaid = true;

  const OrderFilterOptions.allPending()
      : showPending = true,
        showReady = false,
        showDone = false,
        showPaid = true,
        showNotPaid = true;

  const OrderFilterOptions.allReady()
      : showPending = false,
        showReady = true,
        showDone = false,
        showPaid = true,
        showNotPaid = true;

  OrderFilterOptions copyWith({
    bool? showPending,
    bool? showReady,
    bool? showDone,
    bool? showPaid,
    bool? showNotPaid,
  }) {
    return OrderFilterOptions(
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

  bool matchesOrder(Order order) {
    final statusMatch = hasNoStatusSelected ||
        (order.status == OrderStatus.pending && showPending) ||
        (order.status == OrderStatus.ready && showReady) ||
        (order.status == OrderStatus.done && showDone);

    final paymentMatch = hasNoPaymentSelected ||
        (order.isPaid && showPaid) ||
        (!order.isPaid && showNotPaid);

    return statusMatch && paymentMatch;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderFilterOptions &&
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
    return 'OrderFilterOptions(showPending: $showPending, showReady: $showReady, showDone: $showDone, showPaid: $showPaid, showNotPaid: $showNotPaid)';
  }
}

