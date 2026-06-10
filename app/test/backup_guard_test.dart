import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/backup_guard.dart';

String _backupJson({int? customerCount, int? orderCount}) {
  final metadata = <String, dynamic>{};
  if (customerCount != null) metadata['customerCount'] = customerCount;
  if (orderCount != null) metadata['orderCount'] = orderCount;
  return jsonEncode({
    'version': '1.0.0',
    'metadata': metadata,
  });
}

void main() {
  group('BackupGuard.isEmpty', () {
    test('true only when both counts are zero', () {
      expect(BackupGuard.isEmpty(0, 0), isTrue);
      expect(BackupGuard.isEmpty(1, 0), isFalse);
      expect(BackupGuard.isEmpty(0, 1), isFalse);
      expect(BackupGuard.isEmpty(3, 5), isFalse);
    });
  });

  group('BackupGuard.isEmptyBackupJson', () {
    test('blocks a payload reporting 0 customers and 0 orders', () {
      expect(
        BackupGuard.isEmptyBackupJson(_backupJson(customerCount: 0, orderCount: 0)),
        isTrue,
      );
    });

    test('allows a payload with customers', () {
      expect(
        BackupGuard.isEmptyBackupJson(_backupJson(customerCount: 2, orderCount: 0)),
        isFalse,
      );
    });

    test('allows a payload with orders', () {
      expect(
        BackupGuard.isEmptyBackupJson(_backupJson(customerCount: 0, orderCount: 4)),
        isFalse,
      );
    });

    test('fails open when metadata is missing (never block legit backups)', () {
      expect(BackupGuard.isEmptyBackupJson(jsonEncode({'version': '1.0.0'})), isFalse);
    });

    test('fails open when a count key is absent', () {
      expect(BackupGuard.isEmptyBackupJson(_backupJson(customerCount: 0)), isFalse);
      expect(BackupGuard.isEmptyBackupJson(_backupJson(orderCount: 0)), isFalse);
    });

    test('fails open on malformed / non-JSON payloads', () {
      expect(BackupGuard.isEmptyBackupJson('not json at all'), isFalse);
      expect(BackupGuard.isEmptyBackupJson(''), isFalse);
      expect(BackupGuard.isEmptyBackupJson('[1,2,3]'), isFalse);
    });
  });
}
