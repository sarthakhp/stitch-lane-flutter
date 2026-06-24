import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/backend/models/measurement.dart';
import 'package:stitch_lane_app/backend/models/order.dart';
import 'package:stitch_lane_app/domain/services/recordings/customer_recordings_service.dart';
import 'package:stitch_lane_app/domain/services/recordings/entity_recording.dart';

void main() {
  Order order(String id, {String? audio, String? title, required DateTime created}) =>
      Order(
        id: id,
        customerId: 'c1',
        dueDate: created,
        created: created,
        title: title,
        audioFilePaths: audio == null ? const [] : [audio],
      );

  Measurement measurement(String id, {String? audio, required DateTime created}) =>
      Measurement(
        id: id,
        customerId: 'c1',
        description: 'd',
        created: created,
        modified: created,
        audioFilePaths: audio == null ? const [] : [audio],
      );

  group('buildTimeline', () {
    test('includes only entities with an audio path', () {
      final timeline = CustomerRecordingsService.buildTimeline(
        orders: [
          order('o1', audio: '/a.wav', created: DateTime(2026, 1, 2)),
          order('o2', created: DateTime(2026, 1, 3)), // no audio
        ],
        measurements: [
          measurement('m1', audio: '/b.wav', created: DateTime(2026, 1, 1)),
          measurement('m2', created: DateTime(2026, 1, 4)), // no audio
        ],
      );
      expect(timeline.map((e) => e.filePath), ['/a.wav', '/b.wav']);
    });

    test('sorts newest-first across orders and measurements', () {
      final timeline = CustomerRecordingsService.buildTimeline(
        orders: [order('o1', audio: '/old.wav', created: DateTime(2026, 1, 1))],
        measurements: [
          measurement('m1', audio: '/new.wav', created: DateTime(2026, 6, 1)),
        ],
      );
      expect(timeline.first.filePath, '/new.wav');
      expect(timeline.first.kind, EntityRecordingKind.measurement);
      expect(timeline.last.filePath, '/old.wav');
    });

    test('de-dupes a shared dictation path (order creator links many)', () {
      final timeline = CustomerRecordingsService.buildTimeline(
        orders: [
          order('o1', audio: '/shared.wav', created: DateTime(2026, 1, 2)),
          order('o2', audio: '/shared.wav', created: DateTime(2026, 1, 2)),
        ],
        measurements: [
          measurement('m1', audio: '/shared.wav', created: DateTime(2026, 1, 2)),
        ],
      );
      expect(timeline, hasLength(1));
      expect(timeline.single.filePath, '/shared.wav');
    });

    test('order label falls back to "Order" when title is empty', () {
      final timeline = CustomerRecordingsService.buildTimeline(
        orders: [order('o1', audio: '/a.wav', title: '  ', created: DateTime(2026, 1, 1))],
        measurements: const [],
      );
      expect(timeline.single.label, 'Order');
    });
  });
}
