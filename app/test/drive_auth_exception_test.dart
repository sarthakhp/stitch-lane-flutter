import 'package:flutter_test/flutter_test.dart';
import 'package:stitch_lane_app/domain/services/drive_auth_service.dart';

void main() {
  group('DriveAuthException', () {
    test('each reason has a friendly, non-empty message', () {
      for (final reason in DriveAuthReason.values) {
        final ex = DriveAuthException(reason);
        expect(ex.message, isNotEmpty);
        expect(ex.message.toLowerCase(), contains('drive'));
        // No raw jargon leaking to the user.
        expect(ex.message, isNot(contains('Exception')));
      }
    });

    test('toString carries the stable classification sentinel', () {
      for (final reason in DriveAuthReason.values) {
        expect(DriveAuthException(reason).toString(), contains('DriveAuthException'));
      }
    });
  });

  group('DriveAuthException.matches', () {
    test('true for a persisted error string from either reason', () {
      for (final reason in DriveAuthReason.values) {
        // Mirrors how it is stored: BackupTimeService.recordFailed(e.toString()).
        final stored = DriveAuthException(reason).toString();
        expect(DriveAuthException.matches(stored), isTrue);
      }
    });

    test('true even when wrapped by an outer prefix', () {
      final stored = 'Backup failed: ${const DriveAuthException(DriveAuthReason.expired)}';
      expect(DriveAuthException.matches(stored), isTrue);
    });

    test('false for null, empty, and unrelated errors', () {
      expect(DriveAuthException.matches(null), isFalse);
      expect(DriveAuthException.matches(''), isFalse);
      expect(DriveAuthException.matches('SocketException: network down'), isFalse);
      expect(DriveAuthException.matches('Drive access requires something else'), isFalse);
    });
  });
}
