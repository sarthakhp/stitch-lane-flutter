import 'package:flutter/foundation.dart';
import '../../backend/models/customer.dart';
import '../../backend/models/customer_lookup.dart';

class CustomerState extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  /// Cached id→customer index, rebuilt lazily after any change to [_customers].
  CustomerLookup? _lookup;

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// O(1) lookup of customers by id. Prefer this over scanning [customers].
  CustomerLookup get lookup => _lookup ??= CustomerLookup.fromList(_customers);

  /// Drop the cached lookup so it rebuilds on next access.
  void _invalidateLookup() => _lookup = null;

  void setCustomers(List<Customer> customers) {
    _customers = customers;
    _invalidateLookup();
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void addCustomer(Customer customer) {
    _customers.add(customer);
    _invalidateLookup();
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      _invalidateLookup();
      notifyListeners();
    }
  }

  void removeCustomer(String id) {
    _customers.removeWhere((c) => c.id == id);
    _invalidateLookup();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearCustomers() {
    _customers = [];
    _error = null;
    _isLoading = false;
    _invalidateLookup();
    notifyListeners();
  }
}

