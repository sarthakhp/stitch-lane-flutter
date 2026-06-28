import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stitch_lane_app/backend/database/sqlite_database.dart';
import 'package:stitch_lane_app/backend/models/customer.dart';
import 'package:stitch_lane_app/backend/models/order.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_customer_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_measurement_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_order_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sync_outbox.dart';
import 'package:stitch_lane_app/domain/services/sync/fake_firestore_gateway.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_config.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_keys.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_serializer.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_writer_bootstrap.dart';
import 'package:stitch_lane_app/domain/state/customer_state.dart';
import 'package:stitch_lane_app/domain/state/measurement_state.dart';
import 'package:stitch_lane_app/domain/state/order_state.dart';

void main() {
  const uid = 'user1';

  late SqliteCustomerRepository customerRepo;
  late SqliteOrderRepository orderRepo;
  late SqliteMeasurementRepository measurementRepo;
  late FakeFirestoreGateway gateway;
  late CustomerState customerState;
  late OrderState orderState;
  late MeasurementState measurementState;

  Customer customer(String id) =>
      Customer(id: id, name: 'C-$id', created: DateTime(2026, 1, 1));
  Order order(String id, String cid) => Order(
      id: id,
      customerId: cid,
      dueDate: DateTime(2026, 2, 1),
      created: DateTime(2026, 1, 1));

  Future<int> repull() => SyncWriterBootstrap.repullIfEmpty(
        gateway: gateway,
        uid: uid,
        customerRepo: customerRepo,
        orderRepo: orderRepo,
        measurementRepo: measurementRepo,
        customerState: customerState,
        orderState: orderState,
        measurementState: measurementState,
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteDatabase.databaseNameForTesting = 'test_sync_writer_bootstrap.db';
  });

  setUp(() async {
    await SqliteDatabase.deleteDb();
    SyncConfig.setEnabled(true);
    customerRepo = SqliteCustomerRepository();
    orderRepo = SqliteOrderRepository();
    measurementRepo = SqliteMeasurementRepository();
    gateway = FakeFirestoreGateway();
    customerState = CustomerState();
    orderState = OrderState();
    measurementState = MeasurementState();
  });

  tearDown(() async {
    SyncConfig.setEnabled(false);
    await SqliteDatabase.deleteDb();
  });

  test('restores cloud data into an empty primary and never enqueues',
      () async {
    gateway.seedEntity(uid, SyncCollections.customers, 'c1',
        SyncSerializer.docFor(customer('c1')));
    gateway.seedEntity(uid, SyncCollections.orders, 'o1',
        SyncSerializer.docFor(order('o1', 'c1')));

    final restored = await repull();

    expect(restored, 2);
    expect((await customerRepo.getAllCustomers()).map((c) => c.id), ['c1']);
    expect((await orderRepo.getAllOrders()).map((o) => o.id), ['o1']);
    expect(customerState.customers.single.id, 'c1');
    // Pure restore — the mirror write path must not dirty the outbox.
    expect(await SyncOutbox.count(), 0);
  });

  test('no-op when the local DB already has data', () async {
    await customerRepo.upsertFromSync(customer('local1'));
    gateway.seedEntity(uid, SyncCollections.customers, 'cloudX',
        SyncSerializer.docFor(customer('cloudX')));

    final restored = await repull();

    expect(restored, 0);
    // Local untouched — cloud was NOT pulled over existing data.
    expect((await customerRepo.getAllCustomers()).map((c) => c.id), ['local1']);
  });

  test('no-op for a fresh account (local empty and cloud empty)', () async {
    final restored = await repull();
    expect(restored, 0);
    expect(await customerRepo.getAllCustomers(), isEmpty);
  });
}
