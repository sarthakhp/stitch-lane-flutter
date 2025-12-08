import '../../backend/models/customer.dart';
import '../../backend/repositories/customer_repository.dart';
import '../../backend/repositories/order_repository.dart';
import '../state/customer_state.dart';
import '../state/order_state.dart';

class CustomerService {
  static Future<void> loadCustomers(
    CustomerState state,
    CustomerRepository repository,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      final customers = await repository.getAllCustomers();
      state.setCustomers(customers);
    } catch (e) {
      state.setError('Failed to load customers: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> addCustomer(
    CustomerState state,
    CustomerRepository repository,
    Customer customer,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.addCustomer(customer);
      state.addCustomer(customer);
    } catch (e) {
      state.setError('Failed to add customer: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> updateCustomer(
    CustomerState state,
    CustomerRepository repository,
    Customer customer,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.updateCustomer(customer);
      state.updateCustomer(customer);
    } catch (e) {
      state.setError('Failed to update customer: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> deleteCustomer(
    CustomerState customerState,
    CustomerRepository customerRepository,
    String id, {
    OrderState? orderState,
    OrderRepository? orderRepository,
  }) async {
    customerState.setLoading(true);
    customerState.clearError();

    try {
      if (orderRepository != null && orderState != null) {
        await orderRepository.deleteOrdersByCustomerId(id);
        final ordersToRemove = orderState.orders
            .where((order) => order.customerId == id)
            .map((order) => order.id)
            .toList();
        for (final orderId in ordersToRemove) {
          orderState.removeOrder(orderId);
        }
      }

      await customerRepository.deleteCustomer(id);
      customerState.removeCustomer(id);
    } catch (e) {
      customerState.setError('Failed to delete customer: $e');
      rethrow;
    } finally {
      customerState.setLoading(false);
    }
  }
}

