import 'control_doc.dart';
import 'firestore_gateway.dart';

/// Wraps all Firestore operations on the `meta/control` document.
/// The fence check and epoch validation live here; callers never touch
/// Firestore directly.
class SyncControlService {
  SyncControlService._();

  /// Claim writer role for [deviceId].
  ///
  /// [expectedEpoch] is the epoch the caller last read from the control doc
  /// (0 when no doc exists yet — claiming for the first time).
  ///
  /// Throws [StateError] if another device changed the epoch concurrently,
  /// so the caller can re-read the doc and show a message.
  static Future<void> claimWriter({
    required FirestoreGateway gateway,
    required String uid,
    required String deviceId,
    required String deviceName,
    required int expectedEpoch,
  }) async {
    await gateway.runControlTransaction(uid, (current) {
      final currentEpoch = current?.epoch ?? 0;
      if (currentEpoch != expectedEpoch) {
        throw StateError(
          'Another device changed the sync role concurrently '
          '(expected epoch $expectedEpoch, found $currentEpoch). '
          'Please refresh and try again.',
        );
      }
      return ControlDoc(
        writerDeviceId: deviceId,
        writerDeviceName: deviceName,
        epoch: expectedEpoch + 1,
      );
    });
  }

  /// Force-claim the writer role without an epoch guard — for a lost/broken
  /// primary device. The caller MUST:
  ///   1. Take a Drive backup first (rollback artifact).
  ///   2. Show an explicit confirm dialog naming the device being demoted.
  static Future<void> forceTakeover({
    required FirestoreGateway gateway,
    required String uid,
    required String deviceId,
    required String deviceName,
  }) async {
    await gateway.runControlTransaction(uid, (current) {
      final newEpoch = (current?.epoch ?? 0) + 1;
      return ControlDoc(
        writerDeviceId: deviceId,
        writerDeviceName: deviceName,
        epoch: newEpoch,
      );
    });
  }

  /// Publish the writer's current pending-write count into the control doc so
  /// reader devices can gate the handoff "Make this the primary" action on
  /// `pendingCount == 0`. Called by the push pump after each drain cycle.
  static Future<void> updatePendingCount({
    required FirestoreGateway gateway,
    required String uid,
    required int count,
  }) async {
    await gateway.runControlTransaction(uid, (current) {
      if (current == null) return null; // Not a writer — ignore.
      return current.copyWith(pendingCount: count);
    });
  }
}
