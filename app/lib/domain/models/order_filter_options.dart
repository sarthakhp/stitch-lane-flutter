import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';

enum OrderSortMode { dueDate, createdDate }

class OrderFilterOptions {
  final bool showPending;
  final bool showReady;
  final bool showDone;
  final bool showPaid;
  final bool showNotPaid;
  final OrderSortMode sortMode;

  const OrderFilterOptions({
    this.showPending = true,
    this.showReady = true,
    this.showDone = true,
    this.showPaid = true,
    this.showNotPaid = true,
    this.sortMode = OrderSortMode.dueDate,
  });

  const OrderFilterOptions.doneButNotPaid()
      : showPending = false,
        showReady = false,
        showDone = true,
        showPaid = false,
        showNotPaid = true,
        sortMode = OrderSortMode.dueDate;

  const OrderFilterOptions.allPending()
      : showPending = true,
        showReady = false,
        showDone = false,
        showPaid = true,
        showNotPaid = true,
        sortMode = OrderSortMode.dueDate;

  const OrderFilterOptions.allReady()
      : showPending = false,
        showReady = true,
        showDone = false,
        showPaid = true,
        showNotPaid = true,
        sortMode = OrderSortMode.dueDate;

  const OrderFilterOptions.recent()
      : showPending = true,
        showReady = true,
        showDone = true,
        showPaid = true,
        showNotPaid = true,
        sortMode = OrderSortMode.createdDate;

  OrderFilterOptions copyWith({
    bool? showPending,
    bool? showReady,
    bool? showDone,
    bool? showPaid,
    bool? showNotPaid,
    OrderSortMode? sortMode,
  }) {
    return OrderFilterOptions(
      showPending: showPending ?? this.showPending,
      showReady: showReady ?? this.showReady,
      showDone: showDone ?? this.showDone,
      showPaid: showPaid ?? this.showPaid,
      showNotPaid: showNotPaid ?? this.showNotPaid,
      sortMode: sortMode ?? this.sortMode,
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
        other.showNotPaid == showNotPaid &&
        other.sortMode == sortMode;
  }

  @override
  int get hashCode {
    return Object.hash(
      showPending,
      showReady,
      showDone,
      showPaid,
      showNotPaid,
      sortMode,
    );
  }

  @override
  String toString() {
    return 'OrderFilterOptions(showPending: $showPending, showReady: $showReady, showDone: $showDone, showPaid: $showPaid, showNotPaid: $showNotPaid, sortMode: $sortMode)';
  }
}

