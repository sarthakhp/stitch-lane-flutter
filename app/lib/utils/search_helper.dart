import '../backend/models/customer.dart';
import '../backend/models/order.dart';

class SearchHelper {
  static List<String> _splitQuery(String query) {
    return query
        .toLowerCase()
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
  }

  static List<Customer> filterCustomers(
    List<Customer> customers,
    String query,
  ) {
    if (query.isEmpty) {
      return customers;
    }

    final queryWords = _splitQuery(query);

    return customers.where((customer) {
      final nameLower = customer.name.toLowerCase();
      final phoneLower = customer.phoneNumber?.toLowerCase() ?? '';

      return queryWords.every((word) =>
          nameLower.contains(word) || phoneLower.contains(word));
    }).toList();
  }

  static Customer? _findCustomerById(
    List<Customer>? customers,
    String customerId,
  ) {
    if (customers == null) return null;

    try {
      return customers.firstWhere((c) => c.id == customerId);
    } catch (e) {
      return null;
    }
  }

  static List<Order> filterOrders(
    List<Order> orders,
    String query, {
    List<Customer>? customers,
  }) {
    if (query.isEmpty) {
      return orders;
    }

    final queryWords = _splitQuery(query);

    return orders.where((order) {
      final titleLower = order.title?.toLowerCase() ?? '';
      final descriptionLower = order.description?.toLowerCase() ?? '';

      final customer = _findCustomerById(customers, order.customerId);
      final customerNameLower = customer?.name.toLowerCase() ?? '';
      final customerPhoneLower = customer?.phoneNumber?.toLowerCase() ?? '';

      return queryWords.every((word) =>
          titleLower.contains(word) ||
          descriptionLower.contains(word) ||
          customerNameLower.contains(word) ||
          customerPhoneLower.contains(word));
    }).toList();
  }
}

