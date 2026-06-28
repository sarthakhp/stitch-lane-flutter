import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/sync/control_doc.dart';
import 'package:stitch_lane_app/domain/services/sync/doc_change.dart';
import 'package:stitch_lane_app/domain/services/sync/fake_firestore_gateway.dart';

void main() {
  const uid = 'user1';
  const col = 'customers';

  group('FakeFirestoreGateway — entities', () {
    late FakeFirestoreGateway gw;
    setUp(() => gw = FakeFirestoreGateway());

    test('upsert stores and fetchAll returns it', () async {
      await gw.upsert(uid, col, 'c1', {'name': 'Alice'});
      final all = await gw.fetchAll(uid, col);
      expect(all, hasLength(1));
      expect(all.first['name'], 'Alice');
    });

    test('upsert twice updates in place', () async {
      await gw.upsert(uid, col, 'c1', {'name': 'Alice'});
      await gw.upsert(uid, col, 'c1', {'name': 'Alice Updated'});
      final all = await gw.fetchAll(uid, col);
      expect(all, hasLength(1));
      expect(all.first['name'], 'Alice Updated');
    });

    test('delete removes doc', () async {
      await gw.upsert(uid, col, 'c1', {'name': 'Alice'});
      await gw.delete(uid, col, 'c1');
      expect(await gw.fetchAll(uid, col), isEmpty);
    });

    test('upsertBatch stores multiple docs', () async {
      await gw.upsertBatch(uid, col, [
        ('c1', {'name': 'A'}),
        ('c2', {'name': 'B'}),
      ]);
      expect(await gw.fetchAll(uid, col), hasLength(2));
    });

    test('watchCollection emits initial snapshot then changes', () async {
      gw.seedEntity(uid, col, 'c0', {'name': 'Seed'});

      final stream = gw.watchCollection(uid, col);
      final emissions = <List<DocChange>>[];
      final sub = stream.listen(emissions.add);

      // Give the microtask queue a chance to run the initial snapshot.
      await Future<void>.delayed(Duration.zero);

      // Emit a new upsert.
      await gw.upsert(uid, col, 'c1', {'name': 'New'});

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // First emission: initial snapshot (c0 as added).
      expect(emissions.first.map((c) => c.kind),
          everyElement(DocChangeKind.added));
      expect(emissions.first.map((c) => c.id), contains('c0'));

      // Second emission: the upsert of c1.
      final second = emissions[1];
      expect(second, hasLength(1));
      expect(second.first.kind, DocChangeKind.added);
      expect(second.first.id, 'c1');
    });
  });

  group('FakeFirestoreGateway — control doc', () {
    late FakeFirestoreGateway gw;
    setUp(() => gw = FakeFirestoreGateway());

    test('readControl returns null when absent', () async {
      expect(await gw.readControl(uid), isNull);
    });

    test('runControlTransaction creates doc when absent', () async {
      await gw.runControlTransaction(uid, (current) {
        expect(current, isNull);
        return const ControlDoc(
            writerDeviceId: 'd1', writerDeviceName: 'Tablet', epoch: 1);
      });
      final doc = await gw.readControl(uid);
      expect(doc?.writerDeviceId, 'd1');
      expect(doc?.epoch, 1);
    });

    test('runControlTransaction aborts when callback returns null', () async {
      gw.seedControl(uid, const ControlDoc(
          writerDeviceId: 'd1', writerDeviceName: 'Tablet', epoch: 1));
      await gw.runControlTransaction(uid, (_) => null);
      expect((await gw.readControl(uid))?.epoch, 1);
    });

    test('watchControl emits current value on subscribe', () async {
      gw.seedControl(uid, const ControlDoc(
          writerDeviceId: 'd1', writerDeviceName: 'Tablet', epoch: 1));
      final first = await gw.watchControl(uid).first;
      expect(first?.epoch, 1);
    });
  });
}
