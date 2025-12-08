import 'package:hive/hive.dart';
import '../models/customer.dart';
import '../database/database_service.dart';
import 'customer_repository.dart';

class HiveCustomerRepository implements CustomerRepository {
  Box<Customer> get _box => DatabaseService.getCustomersBox();

  @override
  Future<List<Customer>> getAllCustomers() async {
    try {
      return _box.values.toList();
    } catch (e) {
      throw Exception('Failed to get customers: $e');
    }
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    try {
      return _box.values.firstWhere(
        (customer) => customer.id == id,
        orElse: () => throw Exception('Customer not found'),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addCustomer(Customer customer) async {
    try {
      await _box.put(customer.id, customer);
    } catch (e) {
      throw Exception('Failed to add customer: $e');
    }
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    try {
      if (_box.containsKey(customer.id)) {
        await _box.put(customer.id, customer);
      } else {
        throw Exception('Customer not found');
      }
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw Exception('Failed to delete customer: $e');
    }
  }
}

