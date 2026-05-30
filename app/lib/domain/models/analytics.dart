import '../../backend/models/order.dart';
import '../../backend/models/payment_entry.dart';

/// Aggregate paid total for one calendar month.
class MonthSummary {
  final int year;
  final int month;
  final int totalPaid;
  final int paymentCount;

  const MonthSummary({
    required this.year,
    required this.month,
    required this.totalPaid,
    required this.paymentCount,
  });
}

/// Denormalized view of a single payment with everything the UI needs to
/// render a row without re-resolving the customer/order on every build.
class PaymentRecord {
  final PaymentEntry payment;
  final Order order;
  final String customerName;

  const PaymentRecord({
    required this.payment,
    required this.order,
    required this.customerName,
  });
}

/// KPI bundle for an arbitrary date range. Adding a new metric = add a field
/// here, compute it in BusinessAnalyticsService, drop a KpiCard in the grid.
class RangeKpis {
  final int totalPaid;
  final int paymentCount;
  final int averagePayment;
  final int highestPayment;
  final String? topCustomerName;
  final int topCustomerAmount;

  const RangeKpis({
    required this.totalPaid,
    required this.paymentCount,
    required this.averagePayment,
    required this.highestPayment,
    required this.topCustomerName,
    required this.topCustomerAmount,
  });

  static const empty = RangeKpis(
    totalPaid: 0,
    paymentCount: 0,
    averagePayment: 0,
    highestPayment: 0,
    topCustomerName: null,
    topCustomerAmount: 0,
  );
}

/// Money owed across all open orders — the "to-be-collected" counterpart to
/// the paid-totals view.
class OutstandingSummary {
  final int totalUnpaid;
  final int openOrderCount;

  const OutstandingSummary({
    required this.totalUnpaid,
    required this.openOrderCount,
  });

  static const empty = OutstandingSummary(totalUnpaid: 0, openOrderCount: 0);
}

enum PaymentSortBy { date, amount, customerName }

enum SortDirection { ascending, descending }

/// `all` means no filter. The three concrete values mirror [OrderStatus].
enum OrderStatusFilter { all, pending, ready, done }
