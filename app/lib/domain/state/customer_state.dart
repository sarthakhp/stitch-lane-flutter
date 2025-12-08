import 'package:flutter/foundation.dart';
import '../../backend/models/customer.dart';

class CustomerState extends ChangeNotifier {
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setCustomers(List<Customer> customers) {
    _customers = customers;
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
    notifyListeners();
  }

  void updateCustomer(Customer customer) {
    final index = _customers.indexWhere((c) => c.id == customer.id);
    if (index != -1) {
      _customers[index] = customer;
      notifyListeners();
    }
  }

  void removeCustomer(String id) {
    _customers.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

