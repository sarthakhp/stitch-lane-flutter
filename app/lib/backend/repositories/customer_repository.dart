import '../models/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> getAllCustomers();
  
  Future<Customer?> getCustomerById(String id);
  
  Future<void> addCustomer(Customer customer);
  
  Future<void> updateCustomer(Customer customer);
  
  Future<void> deleteCustomer(String id);

  Future<void> clearAll();

  // ── reader mirror path (never enqueues to the sync outbox) ────────────────

  /// Insert-or-replace a row received from the cloud. Unlike [addCustomer] this
  /// records no outbox intent, so a reader's mirror never becomes dirty.
  Future<void> upsertFromSync(Customer customer);

  /// Delete a single row received as a cloud removal. No cascade, no enqueue.
  Future<void> deleteFromSync(String id);

  /// Cold-start reconcile: drop every local row whose id is not in [keepIds]
  /// (rows deleted in the cloud while this device's mirror was absent).
  /// Returns the number of rows removed. Never enqueues.
  Future<int> deleteAllExcept(Iterable<String> keepIds);
}

