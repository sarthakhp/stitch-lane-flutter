import '../../backend/backend.dart';
import '../models/customer_sort.dart';
import '../models/customer_filter_options.dart';

class CustomerSortHelper {
  static DateTime? getEarliestDueDate(String customerId, List<Order> orders) {
    final customerOrders = orders
        .where((order) =>
            order.customerId == customerId && order.status == OrderStatus.pending)
        .toList();

    if (customerOrders.isEmpty) return null;

    customerOrders.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return customerOrders.first.dueDate;
  }

  static int getOrderCount(String customerId, List<Order> orders) {
    return orders.where((order) => order.customerId == customerId).length;
  }

  static int getTotalPendingAmount(String customerId, List<Order> orders) {
    return orders
        .where((order) => order.customerId == customerId && !order.isPaid)
        .fold(0, (sum, order) => sum + order.value);
  }

  static List<Customer> sortCustomers(
    List<Customer> customers,
    List<Order> orders,
    CustomerSort sortType,
  ) {
    final sortedCustomers = List<Customer>.from(customers);

    switch (sortType) {
      case CustomerSort.dueDate:
        sortedCustomers.sort((a, b) {
          final aDueDate = getEarliestDueDate(a.id, orders);
          final bDueDate = getEarliestDueDate(b.id, orders);

          if (aDueDate == null && bDueDate == null) return 0;
          if (aDueDate == null) return 1;
          if (bDueDate == null) return -1;

          return aDueDate.compareTo(bDueDate);
        });
        break;
      case CustomerSort.orderCount:
        sortedCustomers.sort((a, b) {
          final aCount = getOrderCount(a.id, orders);
          final bCount = getOrderCount(b.id, orders);
          return bCount.compareTo(aCount);
        });
        break;
      case CustomerSort.pendingAmount:
        sortedCustomers.sort((a, b) {
          final aAmount = getTotalPendingAmount(a.id, orders);
          final bAmount = getTotalPendingAmount(b.id, orders);
          return bAmount.compareTo(aAmount);
        });
        break;
    }

    return sortedCustomers;
  }

  static List<Customer> sortByCreatedDate(List<Customer> customers) {
    final sortedCustomers = List<Customer>.from(customers);
    sortedCustomers.sort((a, b) => b.created.compareTo(a.created));
    return sortedCustomers;
  }

  static List<Customer> sortCustomersWithMode(
    List<Customer> customers,
    List<Order> orders,
    CustomerSort sortType,
    CustomerSortMode sortMode,
  ) {
    if (sortMode == CustomerSortMode.createdDate) {
      return sortByCreatedDate(customers);
    }
    return sortCustomers(customers, orders, sortType);
  }
}

