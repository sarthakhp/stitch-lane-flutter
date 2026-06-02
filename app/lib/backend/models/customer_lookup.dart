import 'customer.dart';

/// Immutable O(1) lookup of customers by id.
///
/// Built once from a list and shared wherever rows need to resolve their
/// customer (order lists, search, dashboards), replacing repeated linear scans
/// (`firstWhere`) that turn list rendering and search into O(rows × customers).
class CustomerLookup {
  final Map<String, Customer> _byId;

  const CustomerLookup._(this._byId);

  /// An empty lookup; safe to use before customers have loaded.
  static const CustomerLookup empty = CustomerLookup._(<String, Customer>{});

  factory CustomerLookup.fromList(List<Customer> customers) {
    if (customers.isEmpty) return empty;
    return CustomerLookup._({for (final c in customers) c.id: c});
  }

  Customer? byId(String id) => _byId[id];

  String? nameOf(String id) => _byId[id]?.name;

  bool get isEmpty => _byId.isEmpty;

  int get length => _byId.length;
}
