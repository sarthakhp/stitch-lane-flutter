import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/sync/control_doc.dart';
import 'package:stitch_lane_app/domain/services/sync/sync_role.dart';

void main() {
  const myId = 'device-a';
  const otherId = 'device-b';
  const uid = 'user1';

  ControlDoc writerDoc(String deviceId, {int epoch = 1}) => ControlDoc(
        writerDeviceId: deviceId,
        writerDeviceName: 'Test Device',
        epoch: epoch,
      );

  group('computeRole', () {
    test('unconfigured when flag is off', () {
      expect(
        computeRole(
            enabled: false, uid: uid, myDeviceId: myId, control: writerDoc(myId)),
        SyncRole.unconfigured,
      );
    });

    test('unconfigured when uid is null', () {
      expect(
        computeRole(
            enabled: true, uid: null, myDeviceId: myId, control: writerDoc(myId)),
        SyncRole.unconfigured,
      );
    });

    test('unconfigured when myDeviceId is null', () {
      expect(
        computeRole(
            enabled: true, uid: uid, myDeviceId: null, control: writerDoc(myId)),
        SyncRole.unconfigured,
      );
    });

    test('unconfigured when no control doc (unclaimed account)', () {
      expect(
        computeRole(
            enabled: true, uid: uid, myDeviceId: myId, control: null),
        SyncRole.unconfigured,
      );
    });

    test('writer when control doc names this device', () {
      expect(
        computeRole(
            enabled: true,
            uid: uid,
            myDeviceId: myId,
            control: writerDoc(myId)),
        SyncRole.writer,
      );
    });

    test('reader when control doc names another device', () {
      expect(
        computeRole(
            enabled: true,
            uid: uid,
            myDeviceId: myId,
            control: writerDoc(otherId)),
        SyncRole.reader,
      );
    });

    test('canWrite is false only for reader', () {
      final roles = [SyncRole.writer, SyncRole.unconfigured, SyncRole.reader];
      final canWrite = roles.map((r) => r != SyncRole.reader).toList();
      expect(canWrite, [true, true, false]);
    });
  });
}
