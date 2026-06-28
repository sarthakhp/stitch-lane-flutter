import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/sync/control_doc.dart';
import 'package:stitch_lane_app/domain/services/sync/fake_firestore_gateway.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_handoff_service.dart';

void main() {
  const uid = 'user1';
  const me = 'device-me';
  const other = 'device-other';

  late FakeFirestoreGateway gateway;

  Future<bool> online() async => true;
  Future<bool> offline() async => false;

  void seedControl({
    required String writerDeviceId,
    int epoch = 1,
    int pendingCount = 0,
  }) {
    gateway.seedControl(
      uid,
      ControlDoc(
        writerDeviceId: writerDeviceId,
        writerDeviceName: 'Tablet',
        epoch: epoch,
        pendingCount: pendingCount,
      ),
    );
  }

  setUp(() => gateway = FakeFirestoreGateway());

  group('handoff (normal)', () {
    test('blocks when offline', () async {
      seedControl(writerDeviceId: other);
      final status = await SyncHandoffService.handoff(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        isOnline: offline,
      );
      expect(status, HandoffStatus.offline);
    });

    test('no control doc → use enable flow instead', () async {
      final status = await SyncHandoffService.handoff(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        isOnline: online,
      );
      expect(status, HandoffStatus.noControl);
    });

    test('already the writer', () async {
      seedControl(writerDeviceId: me);
      final status = await SyncHandoffService.handoff(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        isOnline: online,
      );
      expect(status, HandoffStatus.alreadyWriter);
    });

    test('blocked while the current writer has un-pushed changes', () async {
      seedControl(writerDeviceId: other, epoch: 4, pendingCount: 3);
      final status = await SyncHandoffService.handoff(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        isOnline: online,
      );
      expect(status, HandoffStatus.writerHasPending);
      // Role unchanged — the other device is still the writer.
      expect(gateway.controlOf(uid)!.writerDeviceId, other);
    });

    test('succeeds when online + drained: bumps epoch, claims this device',
        () async {
      seedControl(writerDeviceId: other, epoch: 4, pendingCount: 0);
      final status = await SyncHandoffService.handoff(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        isOnline: online,
      );
      expect(status, HandoffStatus.success);
      final control = gateway.controlOf(uid)!;
      expect(control.writerDeviceId, me);
      expect(control.epoch, 5);
    });
  });

  group('force takeover', () {
    test('aborts when the rollback snapshot fails', () async {
      seedControl(writerDeviceId: other, epoch: 4, pendingCount: 9);
      final status = await SyncHandoffService.forceTakeover(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        ensureRollbackSnapshot: () async => false,
      );
      expect(status, HandoffStatus.snapshotFailed);
      expect(gateway.controlOf(uid)!.writerDeviceId, other); // unchanged
    });

    test('takes over unconditionally after a snapshot (ignores pendingCount)',
        () async {
      seedControl(writerDeviceId: other, epoch: 4, pendingCount: 9);
      final status = await SyncHandoffService.forceTakeover(
        gateway: gateway,
        uid: uid,
        deviceId: me,
        deviceName: 'Phone',
        ensureRollbackSnapshot: () async => true,
      );
      expect(status, HandoffStatus.success);
      final control = gateway.controlOf(uid)!;
      expect(control.writerDeviceId, me);
      expect(control.epoch, 5);
    });
  });
}
