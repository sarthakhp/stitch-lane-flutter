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
import 'package:stitch_lane_app/domain/services/sync/sync_config.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_keys.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_push_pump.dart';

void main() {
  const uid = 'user1';

  late SqliteCustomerRepository customerRepo;
  late SqliteOrderRepository orderRepo;
  late SqliteMeasurementRepository measurementRepo;
  late SqliteSyncMetaRepository metaRepo;
  late FakeFirestoreGateway gateway;
  late SyncPushPump pump;

  Customer customer(String id) =>
      Customer(id: id, name: 'C-$id', created: DateTime(2026, 1, 1));

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

  SyncPushPump buildPump() => SyncPushPump(
        gateway: gateway,
        metaRepo: metaRepo,
        customerRepo: customerRepo,
        orderRepo: orderRepo,
        measurementRepo: measurementRepo,
        uid: () => uid,
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteDatabase.databaseNameForTesting = 'test_sync_pump.db';
  });

  setUp(() async {
    // Fresh DB per test (the repos all share the SqliteDatabase singleton).
    await SqliteDatabase.deleteDb();
    SyncConfig.setEnabled(true);
    customerRepo = SqliteCustomerRepository();
    orderRepo = SqliteOrderRepository();
    measurementRepo = SqliteMeasurementRepository();
    metaRepo = SqliteSyncMetaRepository();
    gateway = FakeFirestoreGateway();
    pump = buildPump();
  });

  tearDown(() async {
    pump.dispose();
    SyncConfig.setEnabled(false);
    await SqliteDatabase.deleteDb();
  });

  test('enqueue → push clears the outbox and publishes the doc', () async {
    await customerRepo.addCustomer(customer('c1'));
    expect(await SyncOutbox.count(), 1);

    await pump.drain();

    expect(await SyncOutbox.count(), 0);
    final docs = gateway.snapshotOf(uid, SyncCollections.customers);
    expect(docs.keys, ['c1']);
    expect(docs['c1']!['name'], 'C-c1');
  });

  test('two edits to the same row coalesce into one upsert', () async {
    await customerRepo.addCustomer(customer('c1'));
    await customerRepo.updateCustomer(
      Customer(id: 'c1', name: 'renamed', created: DateTime(2026, 1, 1)),
    );

    // PK (collection, entity_id) collapses both edits into a single intent.
    final pending = await SyncOutbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.op, SyncOutbox.opUpsert);

    await pump.drain();

    final docs = gateway.snapshotOf(uid, SyncCollections.customers);
    expect(docs['c1']!['name'], 'renamed');
    expect(await SyncOutbox.count(), 0);
  });

  test('upsert then delete (before any push) collapses to a single delete',
      () async {
    await customerRepo.addCustomer(customer('c1'));
    await customerRepo.deleteCustomer('c1');

    final pending = await SyncOutbox.pending();
    expect(pending, hasLength(1));
    expect(pending.single.op, SyncOutbox.opDelete);

    await pump.drain();

    expect(gateway.snapshotOf(uid, SyncCollections.customers), isEmpty);
    expect(await SyncOutbox.count(), 0);
  });

  test('deleting a customer cascades delete ops for its orders + measurements',
      () async {
    await customerRepo.addCustomer(customer('c1'));
    await orderRepo.addOrder(order('o1', 'c1'));
    await orderRepo.addOrder(order('o2', 'c1'));
    await measurementRepo.addMeasurement(measurement('m1', 'c1'));

    // Publish the initial state so there's something for the deletes to remove.
    await pump.drain();
    expect(gateway.snapshotOf(uid, SyncCollections.orders).keys,
        containsAll(['o1', 'o2']));
    expect(gateway.snapshotOf(uid, SyncCollections.measurements).keys, ['m1']);
    expect(await SyncOutbox.count(), 0);

    await customerRepo.deleteCustomer('c1');

    // One delete op per affected id: customer + 2 orders + 1 measurement.
    final pending = await SyncOutbox.pending();
    expect(pending, hasLength(4));
    expect(pending.every((r) => r.op == SyncOutbox.opDelete), isTrue);
    expect(
      pending.map((r) => '${r.collection}/${r.entityId}').toSet(),
      {
        'customers/c1',
        'orders/o1',
        'orders/o2',
        'measurements/m1',
      },
    );

    await pump.drain();

    expect(gateway.snapshotOf(uid, SyncCollections.customers), isEmpty);
    expect(gateway.snapshotOf(uid, SyncCollections.orders), isEmpty);
    expect(gateway.snapshotOf(uid, SyncCollections.measurements), isEmpty);
    expect(await SyncOutbox.count(), 0);
  });

  test('drain records last_push_at', () async {
    await customerRepo.addCustomer(customer('c1'));
    await pump.drain();
    expect(await metaRepo.get(SyncMetaKeys.lastPushAt), isNotNull);
  });

  test('a fenced device does not push and leaves the outbox intact', () async {
    final fencedPump = SyncPushPump(
      gateway: gateway,
      metaRepo: metaRepo,
      customerRepo: customerRepo,
      orderRepo: orderRepo,
      measurementRepo: measurementRepo,
      uid: () => uid,
      fenceCheck: () async => false,
    );
    addTearDown(fencedPump.dispose);

    await customerRepo.addCustomer(customer('c1'));
    await fencedPump.drain();

    expect(gateway.snapshotOf(uid, SyncCollections.customers), isEmpty);
    expect(await SyncOutbox.count(), 1);
  });

  test('flag-off: repo writes never touch the outbox', () async {
    SyncConfig.setEnabled(false);
    await customerRepo.addCustomer(customer('c1'));
    expect(await SyncOutbox.count(), 0);
  });
}
