import '../../backend/models/customer.dart';
import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';
import '../models/analytics.dart';

/// Pure-function analytics over the in-memory order/customer set. Stateless
/// and UI-agnostic so it can be reused by any screen, tested in isolation,
/// or moved behind an async source later without touching the call sites.
class BusinessAnalyticsService {
  BusinessAnalyticsService._();

  /// Latest [monthsBack] months ending at the current month (inclusive),
  /// most-recent first.
  static List<MonthSummary> monthlyTotals(
    List<Order> orders, {
    int monthsBack = 6,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    return List.generate(monthsBack, (index) {
      final monthStart = DateTime(reference.year, reference.month - index, 1);
      final nextMonthStart =
          DateTime(reference.year, reference.month - index + 1, 1);
      return summaryForRange(orders, monthStart, nextMonthStart);
    });
  }

  /// Bucket payments into [start, end) and return a [MonthSummary]. The
  /// caller decides what `year`/`month` the bucket represents — for a real
  /// calendar month, pass the first-of-month dates.
  static MonthSummary summaryForRange(
    List<Order> orders,
    DateTime start,
    DateTime end,
  ) {
    int total = 0;
    int count = 0;
    for (final order in orders) {
      for (final payment in order.payments) {
        if (_isInRange(payment.date, start, end)) {
          total += payment.amount;
          count++;
        }
      }
    }
    return MonthSummary(
      year: start.year,
      month: start.month,
      totalPaid: total,
      paymentCount: count,
    );
  }

  /// Flatten every payment in [start, end) into a denormalized [PaymentRecord]
  /// with its parent order and customer name. Applies optional status and
  /// customer filters at the order level. Sorted per [sortBy] / [direction].
  static List<PaymentRecord> paymentsInRange(
    List<Order> orders,
    List<Customer> customers,
    DateTime start,
    DateTime end, {
    OrderStatusFilter statusFilter = OrderStatusFilter.all,
    String? customerIdFilter,
    PaymentSortBy sortBy = PaymentSortBy.date,
    SortDirection direction = SortDirection.descending,
  }) {
    final customerNames = _customerNameMap(customers);
    final records = <PaymentRecord>[];

    for (final order in orders) {
      if (!_matchesStatus(order, statusFilter)) continue;
      if (customerIdFilter != null && order.customerId != customerIdFilter) {
        continue;
      }
      for (final payment in order.payments) {
        if (!_isInRange(payment.date, start, end)) continue;
        records.add(PaymentRecord(
          payment: payment,
          order: order,
          customerName: customerNames[order.customerId] ?? 'Unknown',
        ));
      }
    }

    records.sort((a, b) => _comparePayments(a, b, sortBy, direction));
    return records;
  }

  /// Headline metrics for the same range as [paymentsInRange]. KPI cards on
  /// the detail screen are pure projections of this struct.
  static RangeKpis kpisForRange(
    List<Order> orders,
    List<Customer> customers,
    DateTime start,
    DateTime end,
  ) {
    final customerNames = _customerNameMap(customers);

    int total = 0;
    int count = 0;
    int highest = 0;
    final Map<String, int> byCustomer = {};
    final Map<String, DateTime> latestByCustomer = {};

    for (final order in orders) {
      for (final payment in order.payments) {
        if (!_isInRange(payment.date, start, end)) continue;
        total += payment.amount;
        count++;
        if (payment.amount > highest) highest = payment.amount;

        byCustomer.update(
          order.customerId,
          (existing) => existing + payment.amount,
          ifAbsent: () => payment.amount,
        );
        latestByCustomer.update(
          order.customerId,
          (existing) => payment.date.isAfter(existing) ? payment.date : existing,
          ifAbsent: () => payment.date,
        );
      }
    }

    if (count == 0) return RangeKpis.empty;

    String? topCustomerName;
    int topCustomerAmount = 0;
    DateTime? topCustomerLatest;
    byCustomer.forEach((customerId, amount) {
      final latest = latestByCustomer[customerId];
      final isHigherTotal = amount > topCustomerAmount;
      final isTieBreakWinner = amount == topCustomerAmount &&
          latest != null &&
          (topCustomerLatest == null || latest.isAfter(topCustomerLatest!));
      if (isHigherTotal || isTieBreakWinner) {
        topCustomerAmount = amount;
        topCustomerName = customerNames[customerId] ?? 'Unknown';
        topCustomerLatest = latest;
      }
    });

    return RangeKpis(
      totalPaid: total,
      paymentCount: count,
      averagePayment: total ~/ count,
      highestPayment: highest,
      topCustomerName: topCustomerName,
      topCustomerAmount: topCustomerAmount,
    );
  }

  /// Money still owed across every order that isn't fully paid.
  static OutstandingSummary outstanding(List<Order> orders) {
    int total = 0;
    int openCount = 0;
    for (final order in orders) {
      if (order.isPaid) continue;
      final remaining = order.value - order.totalPaidAmount;
      if (remaining <= 0) continue;
      total += remaining;
      openCount++;
    }
    return OutstandingSummary(totalUnpaid: total, openOrderCount: openCount);
  }

  // ── internals ────────────────────────────────────────────────────────────

  static bool _isInRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && date.isBefore(end);
  }

  static bool _matchesStatus(Order order, OrderStatusFilter filter) {
    switch (filter) {
      case OrderStatusFilter.all:
        return true;
      case OrderStatusFilter.pending:
        return order.status == OrderStatus.pending;
      case OrderStatusFilter.ready:
        return order.status == OrderStatus.ready;
      case OrderStatusFilter.done:
        return order.status == OrderStatus.done;
    }
  }

  static Map<String, String> _customerNameMap(List<Customer> customers) {
    return {for (final c in customers) c.id: c.name};
  }

  static int _comparePayments(
    PaymentRecord a,
    PaymentRecord b,
    PaymentSortBy sortBy,
    SortDirection direction,
  ) {
    int compared;
    switch (sortBy) {
      case PaymentSortBy.date:
        compared = a.payment.date.compareTo(b.payment.date);
      case PaymentSortBy.amount:
        compared = a.payment.amount.compareTo(b.payment.amount);
      case PaymentSortBy.customerName:
        compared =
            a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase());
    }
    return direction == SortDirection.ascending ? compared : -compared;
  }
}
