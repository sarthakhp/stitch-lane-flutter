import '../models/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAllCustomers();
  
  Future<Customer?> getCustomerById(String id);
  
  Future<void> addCustomer(Customer customer);
  
  Future<void> updateCustomer(Customer customer);
  
  Future<void> deleteCustomer(String id);
}

