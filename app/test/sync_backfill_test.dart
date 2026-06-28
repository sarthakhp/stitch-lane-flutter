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
import 'package:stitch_lane_app/domain/services/sync/sync_backfill_service.dart';
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
  Order order(String id, String cid) => Order(
      id: id,
      customerId: cid,
      dueDate: DateTime(2026, 2, 1),
      created: DateTime(2026, 1, 1));
  Measurement measurement(String id, String cid) => Measurement(
      id: id,
      customerId: cid,
      description: 'm',
      created: DateTime(2026, 1, 1),
      modified: DateTime(2026, 1, 1));

  // Seed local rows WITHOUT touching the outbox (mirror write path).
  Future<void> seedLocal() async {
    await customerRepo.upsertFromSync(customer('c1'));
    await customerRepo.upsertFromSync(customer('c2'));
    await orderRepo.upsertFromSync(order('o1', 'c1'));
    await orderRepo.upsertFromSync(order('o2', 'c2'));
    await measurementRepo.upsertFromSync(measurement('m1', 'c1'));
  }

  SyncBackfillService buildService({
    required Future<bool> Function() snapshot,
  }) =>
      SyncBackfillService(
        customerRepo: customerRepo,
        orderRepo: orderRepo,
        measurementRepo: measurementRepo,
        metaRepo: metaRepo,
        ensureRollbackSnapshot: snapshot,
        drain: pump.drain,
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteDatabase.databaseNameForTesting = 'test_sync_backfill.db';
  });

  setUp(() async {
    await SqliteDatabase.deleteDb();
    SyncConfig.setEnabled(true);
    customerRepo = SqliteCustomerRepository();
    orderRepo = SqliteOrderRepository();
    measurementRepo = SqliteMeasurementRepository();
    metaRepo = SqliteSyncMetaRepository();
    gateway = FakeFirestoreGateway();
    pump = SyncPushPump(
      gateway: gateway,
      metaRepo: metaRepo,
      customerRepo: customerRepo,
      orderRepo: orderRepo,
      measurementRepo: measurementRepo,
      uid: () => uid,
    );
  });

  tearDown(() async {
    pump.dispose();
    SyncConfig.setEnabled(false);
    await SqliteDatabase.deleteDb();
  });

  test('publishes every local row to the cloud and marks done', () async {
    await seedLocal();
    final service = buildService(snapshot: () async => true);

    final result = await service.run();

    expect(result.status, BackfillStatus.success);
    expect(result.published, 5);
    expect(gateway.snapshotOf(uid, SyncCollections.customers).keys,
        containsAll(['c1', 'c2']));
    expect(gateway.snapshotOf(uid, SyncCollections.orders).keys,
        containsAll(['o1', 'o2']));
    expect(gateway.snapshotOf(uid, SyncCollections.measurements).keys, ['m1']);
    expect(await SyncOutbox.count(), 0);
    expect(await SyncBackfillService.isDone(metaRepo), isTrue);
  });

  test('is idempotent — a second run is a no-op', () async {
    await seedLocal();
    await buildService(snapshot: () async => true).run();

    // Add a row after the first backfill; a re-run must NOT publish it (done).
    await customerRepo.upsertFromSync(customer('c3'));
    final second = await buildService(snapshot: () async => true).run();

    expect(second.status, BackfillStatus.alreadyDone);
    expect(second.published, 0);
    expect(gateway.snapshotOf(uid, SyncCollections.customers).keys.contains('c3'),
        isFalse);
  });

  test('aborts and publishes nothing when the rollback snapshot fails',
      () async {
    await seedLocal();
    final service = buildService(snapshot: () async => false);

    final result = await service.run();

    expect(result.status, BackfillStatus.snapshotFailed);
    expect(gateway.snapshotOf(uid, SyncCollections.customers), isEmpty);
    expect(await SyncOutbox.count(), 0);
    expect(await SyncBackfillService.isDone(metaRepo), isFalse);
  });

  test('reports progress up to the total row count', () async {
    await seedLocal();
    final service = buildService(snapshot: () async => true);

    var lastDone = 0;
    var lastTotal = 0;
    await service.run(onProgress: (done, total) {
      lastDone = done;
      lastTotal = total;
    });

    expect(lastTotal, 5);
    expect(lastDone, 5);
  });
}
