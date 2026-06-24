import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/backend/backend.dart';
import 'package:stitch_lane_app/domain/services/backup_import_service.dart';

/// JSON round-trip (encode → decode) so the test also catches anything the
/// real backup zip would hit (DateTimes must serialize to strings, etc.).
Map<String, dynamic> _rt(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group('backup model round-trip (no field dropped)', () {
    test('Customer', () {
      final c = Customer(
        id: 'c1',
        name: 'Asha',
        phoneNumber: '9876543210',
        description: 'regular',
        created: DateTime(2026, 6, 9, 10, 30),
      );
      final r = Customer.fromJson(_rt(c.toJson()));
      expect(r.id, c.id);
      expect(r.name, c.name);
      expect(r.phoneNumber, c.phoneNumber);
      expect(r.description, c.description);
      expect(r.created, c.created);
    });

    test('Order with payments, images, status, paymentDate', () {
      final o = Order(
        id: 'o1',
        customerId: 'c1',
        title: 'Blouse',
        dueDate: DateTime(2026, 6, 20),
        description: '- **Fabric:** silk',
        created: DateTime(2026, 6, 9, 10, 30),
        status: OrderStatus.ready,
        value: 1550,
        isPaid: true,
        imagePaths: const ['/old/x/a.jpg', '/old/x/b.jpg'],
        paymentDate: DateTime(2026, 6, 10),
        payments: [
          PaymentEntry(id: 'p1', date: DateTime(2026, 6, 10), amount: 500),
          PaymentEntry(id: 'p2', date: DateTime(2026, 6, 11), amount: 1050),
        ],
        totalPaidAmount: 1550,
      );
      final r = Order.fromJson(_rt(o.toJson()));
      expect(r.id, o.id);
      expect(r.customerId, o.customerId);
      expect(r.title, o.title);
      expect(r.dueDate, o.dueDate);
      expect(r.description, o.description);
      expect(r.created, o.created);
      expect(r.status, OrderStatus.ready);
      expect(r.value, 1550);
      expect(r.imagePaths, o.imagePaths);
      expect(r.paymentDate, o.paymentDate);
      expect(r.totalPaidAmount, 1550);
      expect(r.payments.length, 2);
      expect(r.payments[0].id, 'p1');
      expect(r.payments[0].amount, 500);
      expect(r.payments[1].date, DateTime(2026, 6, 11));
    });

    test('Order with undecided price (null value) stays null', () {
      final o = Order(
        id: 'o2',
        customerId: 'c1',
        dueDate: DateTime(2026, 1, 1),
        created: DateTime(2026, 1, 1),
        value: null,
      );
      final r = Order.fromJson(_rt(o.toJson()));
      expect(r.value, isNull);
    });

    test('Measurement (incl. audioFilePaths)', () {
      final m = Measurement(
        id: 'm1',
        customerId: 'c1',
        description: '### Blouse\n- **Bust:** 39',
        created: DateTime(2026, 6, 9, 10, 0),
        modified: DateTime(2026, 6, 9, 10, 5),
        audioFilePaths: const [
          '/data/app/audio_backups/2026-06-09T10-00-00.wav',
          '/data/app/audio_backups/2026-06-09T10-02-00.wav',
        ],
      );
      final r = Measurement.fromJson(_rt(m.toJson()));
      expect(r.id, m.id);
      expect(r.customerId, m.customerId);
      expect(r.description, m.description);
      expect(r.created, m.created);
      expect(r.modified, m.modified);
      expect(r.audioFilePaths, m.audioFilePaths);
    });

    test('Measurement legacy audioFilePath JSON migrates to a 1-element list', () {
      final r = Measurement.fromJson({
        'id': 'm1',
        'customerId': 'c1',
        'description': 'd',
        'created': DateTime(2026, 1, 1).toIso8601String(),
        'modified': DateTime(2026, 1, 1).toIso8601String(),
        'audioFilePath': '/legacy/one.wav',
      });
      expect(r.audioFilePaths, ['/legacy/one.wav']);
    });

    test('AppSettings (all fields incl. debugLogs, sttModel, ttsSpeaker)', () {
      final input = <String, dynamic>{
        'dueDateWarningThreshold': 5,
        'pendingOrdersReminderEnabled': true,
        'pendingOrdersReminderTime': '09:15',
        'autoBackupEnabled': true,
        'autoBackupTime': '02:30',
        'lastBackupTime': '2026-06-09T10:00:00.000',
        'debugLogsEnabled': false,
        'aiChatModel': 'gemini:gemini-2.5-flash',
        'aiFormattingModel': 'gemini:fmt',
        'lastBackupStatus': 'success',
        'lastBackupError': null,
        'sttModel': 'gemini:gemini-3.1-flash-lite',
        'ttsSpeaker': 'anushka',
      };
      final out = AppSettings.fromJson(input).toJson();
      for (final key in input.keys) {
        expect(out[key], input[key], reason: 'settings field "$key" must survive round-trip');
      }
    });
  });

  group('import media path rewrite', () {
    test('rewrites a foreign absolute path to this device dir by file name', () {
      expect(
        BackupImportService.localMediaPath('/new/order_images', '/old/dev/order_images/a.jpg'),
        '/new/order_images/a.jpg',
      );
      expect(
        BackupImportService.localMediaPath(
            '/new/audio_backups', '/data/old/audio_backups/2026-06-09T10-00-00.wav'),
        '/new/audio_backups/2026-06-09T10-00-00.wav',
      );
    });

    test('handles a bare file name (no directory)', () {
      expect(
        BackupImportService.localMediaPath('/new/audio_backups', 'measurement_x.m4a'),
        '/new/audio_backups/measurement_x.m4a',
      );
    });
  });
}
