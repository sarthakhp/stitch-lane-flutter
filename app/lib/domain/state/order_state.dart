import 'package:flutter/foundation.dart';
import '../../backend/models/order.dart';
import '../../backend/models/order_status.dart';

class OrderState extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int getPendingOrderCount(String customerId) {
    return _orders
        .where((order) =>
            order.customerId == customerId &&
            order.status == OrderStatus.pending)
        .length;
  }

  int getReadyOrderCount(String customerId) {
    return _orders
        .where((order) =>
            order.customerId == customerId &&
            order.status == OrderStatus.ready)
        .length;
  }

  int getTotalUnpaidAmount(String customerId) {
    return _orders
        .where((order) =>
            order.customerId == customerId &&
            !order.isPaid)
        .fold(0, (sum, order) => sum + order.value);
  }

  bool hasCustomerPendingOrders(String customerId) {
    return _orders.any((order) =>
        order.customerId == customerId &&
        order.status == OrderStatus.pending);
  }

  bool hasCustomerReadyOrders(String customerId) {
    return _orders.any((order) =>
        order.customerId == customerId &&
        order.status == OrderStatus.ready);
  }

  bool hasCustomerDoneOrders(String customerId) {
    return _orders.any((order) =>
        order.customerId == customerId &&
        order.status == OrderStatus.done);
  }

  bool hasCustomerPaidOrders(String customerId) {
    return _orders.any((order) =>
        order.customerId == customerId &&
        order.isPaid);
  }

  bool hasCustomerUnpaidOrders(String customerId) {
    return _orders.any((order) =>
        order.customerId == customerId &&
        !order.isPaid);
  }

  void setOrders(List<Order> orders) {
    _orders = orders;
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

  void addOrder(Order order) {
    _orders.add(order);
    notifyListeners();
  }

  void updateOrder(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      _orders[index] = order;
      notifyListeners();
    }
  }

  void removeOrder(String id) {
    _orders.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearOrders() {
    _orders = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

