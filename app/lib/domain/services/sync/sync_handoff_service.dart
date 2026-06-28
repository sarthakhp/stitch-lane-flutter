import '../../../utils/app_logger.dart';
import 'firestore_gateway.dart';
import 'sync_control_service.dart';

enum HandoffStatus {
  /// This device is now the writer.
  success,

  /// Device is offline — handoff needs a live connection to claim safely.
  offline,

  /// No control doc exists yet — use the initial "Enable as primary" + backfill
  /// flow instead of a handoff.
  noControl,

  /// This device already holds the writer role.
  alreadyWriter,

  /// The current writer still has un-pushed changes (`pendingCount > 0`).
  /// Blocking the handoff is what prevents data loss — wait for it to drain.
  writerHasPending,

  /// Another device changed the role concurrently; re-read and retry.
  raced,

  /// Force takeover aborted because the rollback snapshot couldn't be taken.
  snapshotFailed,
}

/// Moves the writer role between devices.
///
/// Two paths, deliberately separate:
///  • [handoff] — the safe, everyday path from a reader. Gated on being online
///    AND the current writer having fully drained (`pendingCount == 0`), then a
///    transactional epoch bump. No divergence is possible because there was
///    nothing left to push.
///  • [forceTakeover] — the break-glass path for a lost / broken / sold primary.
///    Takes a rollback snapshot first, then bumps the epoch unconditionally.
///    The caller MUST have shown a confirm dialog naming the device being
///    demoted and warning that its un-synced changes will be set aside (the
///    demoted device's fence will quarantine them).
class SyncHandoffService {
  SyncHandoffService._();

  static Future<HandoffStatus> handoff({
    required FirestoreGateway gateway,
    required String uid,
    required String deviceId,
    required String deviceName,
    required Future<bool> Function() isOnline,
  }) async {
    if (!await isOnline()) return HandoffStatus.offline;

    final control = await gateway.readControl(uid);
    if (control == null) return HandoffStatus.noControl;
    if (control.writerDeviceId == deviceId) return HandoffStatus.alreadyWriter;
    if (control.pendingCount != 0) return HandoffStatus.writerHasPending;

    try {
      await SyncControlService.claimWriter(
        gateway: gateway,
        uid: uid,
        deviceId: deviceId,
        deviceName: deviceName,
        expectedEpoch: control.epoch,
      );
      AppLogger.info('[SyncHandoff] Claimed writer at epoch ${control.epoch + 1}.');
      return HandoffStatus.success;
    } on StateError {
      // Epoch moved between our read and the transaction.
      return HandoffStatus.raced;
    }
  }

  static Future<HandoffStatus> forceTakeover({
    required FirestoreGateway gateway,
    required String uid,
    required String deviceId,
    required String deviceName,
    required Future<bool> Function() ensureRollbackSnapshot,
  }) async {
    AppLogger.info('[SyncHandoff] Force takeover — taking rollback snapshot.');
    if (!await ensureRollbackSnapshot()) {
      AppLogger.error('[SyncHandoff] Rollback snapshot failed — aborting takeover.');
      return HandoffStatus.snapshotFailed;
    }

    await SyncControlService.forceTakeover(
      gateway: gateway,
      uid: uid,
      deviceId: deviceId,
      deviceName: deviceName,
    );
    AppLogger.warning('[SyncHandoff] Force takeover complete.');
    return HandoffStatus.success;
  }
}
