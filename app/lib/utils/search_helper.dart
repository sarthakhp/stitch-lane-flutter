import '../backend/models/customer.dart';
import '../backend/models/order.dart';

class SearchHelper {
  static List<Customer> filterCustomers(
    List<Customer> customers,
    String query,
  ) {
    if (query.isEmpty) {
      return customers;
    }

    final lowerQuery = query.toLowerCase().trim();

    return customers.where((customer) {
      final nameLower = customer.name.toLowerCase();
      final phoneLower = customer.phoneNumber?.toLowerCase() ?? '';

      return nameLower.contains(lowerQuery) ||
          phoneLower.contains(lowerQuery);
    }).toList();
  }

  static List<Order> filterOrders(
    List<Order> orders,
    String query,
  ) {
    if (query.isEmpty) {
      return orders;
    }

    final lowerQuery = query.toLowerCase().trim();

    return orders.where((order) {
      final titleLower = order.title.toLowerCase();
      final descriptionLower = order.description?.toLowerCase() ?? '';

      return titleLower.contains(lowerQuery) ||
          descriptionLower.contains(lowerQuery);
    }).toList();
  }
}

