import '../../../backend/database/sqlite_database.dart';
import '../../../backend/models/customer.dart';
import '../../../backend/models/measurement.dart';
import '../../../backend/models/order.dart';
import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../utils/app_logger.dart';
import '../../state/customer_state.dart';
import '../../state/measurement_state.dart';
import '../../state/order_state.dart';
import '../customer_service.dart';
import '../measurement_service.dart';
import '../order_service.dart';
import 'firestore_gateway.dart';
import 'sync_keys.dart';

/// Recovers a primary device whose local data was wiped while the cloud still
/// holds it — most importantly after a sign-out + sign-in on the writer, which
/// clears local data but leaves the control doc naming this device. A writer
/// never pulls, so without this it would resume with an empty database and the
/// user would see nothing (the cloud copy is safe, just invisible).
///
/// [repullIfEmpty] does a one-time reader-style pull of the full cloud snapshot
/// before the device resumes writing. It is a strict no-op when the local DB
/// already has data (normal writer) or when the cloud is also empty (genuinely
/// fresh account), so it is safe to call on every writer start.
class SyncWriterBootstrap {
  SyncWriterBootstrap._();

  static Future<int> repullIfEmpty({
    required FirestoreGateway gateway,
    required String uid,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required CustomerState customerState,
    required OrderState orderState,
    required MeasurementState measurementState,
  }) async {
    // Local has data → a normal writer, nothing to recover. Short-circuit on
    // the first non-empty collection so a populated writer pays one cheap query.
    if ((await customerRepo.getAllCustomers()).isNotEmpty) return 0;
    if ((await orderRepo.getAllOrders()).isNotEmpty) return 0;
    if ((await measurementRepo.getAllMeasurements()).isNotEmpty) return 0;

    // Local empty — see if the cloud has anything to restore.
    final customers = await gateway.fetchAll(uid, SyncCollections.customers);
    final orders = await gateway.fetchAll(uid, SyncCollections.orders);
    final measurements =
        await gateway.fetchAll(uid, SyncCollections.measurements);
    final total = customers.length + orders.length + measurements.length;
    if (total == 0) return 0; // fresh account — normal writer start.

    AppLogger.warning(
        '[SyncWriterBootstrap] Local empty but cloud has $total row(s) — '
        'restoring before this device resumes writing.');

    // FK off: parents and children arrive in fixed order here, but disabling is
    // cheap insurance and matches the applier's mirror-write path.
    await SqliteDatabase.withForeignKeysDisabled(() async {
      for (final data in customers) {
        await customerRepo.upsertFromSync(Customer.fromJson(data));
      }
      for (final data in orders) {
        await orderRepo.upsertFromSync(Order.fromJson(data));
      }
      for (final data in measurements) {
        await measurementRepo.upsertFromSync(Measurement.fromJson(data));
      }
    });

    await CustomerService.loadCustomers(customerState, customerRepo);
    await OrderService.loadOrders(orderState, orderRepo);
    await MeasurementService.loadMeasurements(measurementState, measurementRepo);

    AppLogger.info('[SyncWriterBootstrap] Restored $total row(s) from cloud.');
    return total;
  }
}
