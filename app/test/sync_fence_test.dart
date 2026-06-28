import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:stitch_lane_app/backend/database/sqlite_database.dart';
import 'package:stitch_lane_app/backend/models/customer.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_customer_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_measurement_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sqlite_order_repository.dart';
import 'package:stitch_lane_app/backend/repositories/sync_outbox.dart';
import 'package:stitch_lane_app/backend/repositories/sync_quarantine.dart';
import 'package:stitch_lane_app/domain/services/sync/control_doc.dart';
import 'package:stitch_lane_app/domain/services/sync/fake_firestore_gateway.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_config.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_fence_service.dart';

void main() {
  const uid = 'user1';
  const me = 'device-me';
  const other = 'device-other';

  late SqliteCustomerRepository customerRepo;
  late SqliteOrderRepository orderRepo;
  late SqliteMeasurementRepository measurementRepo;
  late FakeFirestoreGateway gateway;
  late SyncFenceService fence;

  Customer customer(String id) =>
      Customer(id: id, name: 'C-$id', created: DateTime(2026, 1, 1));

  void seedControl(String writerDeviceId, int epoch) {
    gateway.seedControl(
      uid,
      ControlDoc(
        writerDeviceId: writerDeviceId,
        writerDeviceName: 'Tablet',
        epoch: epoch,
      ),
    );
  }

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SqliteDatabase.databaseNameForTesting = 'test_sync_fence.db';
  });

  setUp(() async {
    await SqliteDatabase.deleteDb();
    SyncConfig.setEnabled(true);
    customerRepo = SqliteCustomerRepository();
    orderRepo = SqliteOrderRepository();
    measurementRepo = SqliteMeasurementRepository();
    gateway = FakeFirestoreGateway();
    fence = SyncFenceService(
      gateway: gateway,
      customerRepo: customerRepo,
      orderRepo: orderRepo,
      measurementRepo: measurementRepo,
    );
  });

  tearDown(() async {
    SyncConfig.setEnabled(false);
    await SqliteDatabase.deleteDb();
  });

  test('allows push when control names this device at our epoch', () async {
    seedControl(me, 3);
    await customerRepo.addCustomer(customer('c1')); // 1 pending upsert

    final allowed =
        await fence.allowedToPush(uid: uid, myDeviceId: me, myEpoch: 3);

    expect(allowed, isTrue);
    expect(await SyncOutbox.count(), 1); // untouched
    expect(await SyncQuarantine.count(), 0);
  });

  test('allows push when no control doc exists yet', () async {
    final allowed =
        await fence.allowedToPush(uid: uid, myDeviceId: me, myEpoch: 0);
    expect(allowed, isTrue);
  });

  test('fences when another device is the writer: quarantine + clear + deny',
      () async {
    seedControl(other, 5);
    await customerRepo.addCustomer(customer('c1'));
    await customerRepo.addCustomer(customer('c2'));
    expect(await SyncOutbox.count(), 2);

    final allowed =
        await fence.allowedToPush(uid: uid, myDeviceId: me, myEpoch: 4);

    expect(allowed, isFalse);
    expect(await SyncOutbox.count(), 0); // cleared
    expect(await SyncQuarantine.count(), 2); // nothing lost

    final rows = await SyncQuarantine.all();
    final c1 = rows.firstWhere((r) => r.entityId == 'c1');
    expect(c1.op, SyncOutbox.opUpsert);
    expect(c1.payload, isNotNull);
    // Payload is the entity snapshot — the user's data is preserved for review.
    expect((jsonDecode(c1.payload!) as Map)['name'], 'C-c1');
  });

  test('fences when the epoch has advanced past ours (same device id)',
      () async {
    seedControl(me, 9); // a takeover bumped epoch beyond what we claimed under
    await customerRepo.addCustomer(customer('c1'));

    final allowed =
        await fence.allowedToPush(uid: uid, myDeviceId: me, myEpoch: 7);

    expect(allowed, isFalse);
    expect(await SyncOutbox.count(), 0);
    expect(await SyncQuarantine.count(), 1);
  });

  test('a delete op is quarantined with a null payload', () async {
    seedControl(other, 2);
    await customerRepo.addCustomer(customer('c1'));
    await customerRepo.deleteCustomer('c1'); // coalesces to a single delete

    final allowed =
        await fence.allowedToPush(uid: uid, myDeviceId: me, myEpoch: 1);

    expect(allowed, isFalse);
    final rows = await SyncQuarantine.all();
    expect(rows, hasLength(1));
    expect(rows.single.op, SyncOutbox.opDelete);
    expect(rows.single.payload, isNull);
  });
}
