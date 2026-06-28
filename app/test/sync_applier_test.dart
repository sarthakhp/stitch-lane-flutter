import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stitch_lane_app/backend/database/sqlite_database.dart';
import 'package:stitch_lane_app/backend/models/customer.dart';
import 'package:stitch_lane_app/backend/models/measurement.dart';
import 'package:stitch_lane_app/backend/models/order.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_customer_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_measurement_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_order_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_sync_meta_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sync_outbox.dart';
import 'package:stitch_lane_app/domain/services/sync/fake_firestore_gateway.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_applier.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_config.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_keys.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_serializer.dart';
import 'package:stitch_lane_app/domain/state/customer_state.dart';
import 'package:stitch_lane_app/domain/state/measurement_state.dart';
import 'package:stitch_lane_app/domain/state/order_state.dart';

void main() {
  const uid = 'user1';

  late SqliteCustomerRepository customerRepo;
  late SqliteOrderRepository orderRepo;
  late SqliteMeasurementRepository measurementRepo;
  late SqliteSyncMetaRepository metaRepo;
  late FakeFirestoreGateway gateway;
  late CustomerState customerState;
  late OrderState orderState;
  late MeasurementState measurementState;
  late SyncApplier applier;

  Customer customer(String id, {String? name}) =>
      Customer(id: id, name: name ?? 'C-$id', created: DateTime(2026, 1, 1));

  Order order(String id, String customerId) => Order(
        id: id,
        customerId: customerId,
        dueDate: DateTime(2026, 2, 1),
        created: DateTime(2026, 1, 1),
      );

  Measurement measurement(String id, String customerId) => Measurement(
        id: id,
        customerId: customerId,
        description: 'm-$id',
        created: DateTime(2026, 1, 1),
        modified: DateTime(2026, 1, 1),
      );

  SyncApplier buildApplier() => SyncApplier(
        gateway: gateway,
        metaRepo: metaRepo,
        uid: () => uid,
        customerRepo: customerRepo,
        orderRepo: orderRepo,
        measurementRepo: measurementRepo,
        customerState: customerState,
        orderState: orderState,
        measurementState: measurementState,
      );

  // Pump the fake's scheduled emissions, then wait for the applier's serialized
  // batch chain to drain.
  Future<void> sync() async {
    await pumpEventQueue();
    await applier.settle();
    await pumpEventQueue();
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteDatabase.databaseNameForTesting = 'test_sync_applier.db';
  });

  setUp(() async {
    await SqliteDatabase.deleteDb();
    SyncConfig.setEnabled(true);
    customerRepo = SqliteCustomerRepository();
    orderRepo = SqliteOrderRepository();
    measurementRepo = SqliteMeasurementRepository();
    metaRepo = SqliteSyncMetaRepository();
    gateway = FakeFirestoreGateway();
    customerState = CustomerState();
    orderState = OrderState();
    measurementState = MeasurementState();
    applier = buildApplier();
  });

  tearDown(() async {
    applier.dispose();
    SyncConfig.setEnabled(false);
    await SqliteDatabase.deleteDb();
  });

  test('initial snapshot mirrors cloud docs into local DB + state', () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    gateway.seedEntity(
        uid, SyncCollections.orders, 'o1', SyncSerializer.docFor(order('o1', 'c1')));
    gateway.seedEntity(uid, SyncCollections.measurements, 'm1',
        SyncSerializer.docFor(measurement('m1', 'c1')));

    applier.start();
    await sync();

    expect((await customerRepo.getAllCustomers()).map((c) => c.id), ['c1']);
    expect((await orderRepo.getAllOrders()).map((o) => o.id), ['o1']);
    expect((await measurementRepo.getAllMeasurements()).map((m) => m.id), ['m1']);

    expect(customerState.customers.single.name, 'C-c1');
    expect(orderState.orders.single.id, 'o1');
    expect(measurementState.measurements.single.id, 'm1');
  });

  test('modified doc updates the mirror', () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    applier.start();
    await sync();

    await gateway.upsertBatch(uid, SyncCollections.customers,
        [('c1', SyncSerializer.docFor(customer('c1', name: 'renamed')))]);
    await sync();

    expect((await customerRepo.getCustomerById('c1'))!.name, 'renamed');
    expect(customerState.customers.single.name, 'renamed');
  });

  test('removed doc deletes from the mirror', () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    applier.start();
    await sync();
    expect(await customerRepo.getCustomerById('c1'), isNotNull);

    await gateway.delete(uid, SyncCollections.customers, 'c1');
    await sync();

    expect(await customerRepo.getCustomerById('c1'), isNull);
    expect(customerState.customers, isEmpty);
  });

  test('cold-start reconcile drops local rows absent from the snapshot',
      () async {
    // A row left over from a previous mirror that has since been deleted in
    // the cloud. Seeded via the sync path so it carries no outbox intent.
    await customerRepo.upsertFromSync(customer('stale'));
    gateway.seedEntity(uid, SyncCollections.customers, 'cloud1',
        SyncSerializer.docFor(customer('cloud1')));

    applier.start();
    await sync();

    final ids = (await customerRepo.getAllCustomers()).map((c) => c.id).toSet();
    expect(ids, {'cloud1'});
    expect(ids.contains('stale'), isFalse);
  });

  test('applier writes never enqueue to the outbox (mirror stays clean)',
      () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    applier.start();
    await sync();

    await gateway.upsertBatch(uid, SyncCollections.customers,
        [('c1', SyncSerializer.docFor(customer('c1', name: 'x')))]);
    await sync();
    await gateway.delete(uid, SyncCollections.customers, 'c1');
    await sync();

    expect(await SyncOutbox.count(), 0);
  });

  test('records last_pull_at after applying', () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    applier.start();
    await sync();

    expect(await metaRepo.get(SyncMetaKeys.lastPullAt), isNotNull);
  });

  test('bootstrapped completes after the first snapshot of every collection',
      () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    applier.start();

    // Even with empty orders/measurements collections, each fires an initial
    // (possibly empty) snapshot, so the reader becomes ready.
    await applier.bootstrapped.timeout(const Duration(seconds: 5));
    expect(await customerRepo.getCustomerById('c1'), isNotNull);
  });

  test('out-of-order child before parent still mirrors (FK tolerated)',
      () async {
    // Order references a customer that isn't in the snapshot yet.
    gateway.seedEntity(
        uid, SyncCollections.orders, 'o1', SyncSerializer.docFor(order('o1', 'cX')));
    applier.start();
    await sync();

    expect((await orderRepo.getAllOrders()).map((o) => o.id), ['o1']);
  });
}
