import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../backend/repositories/sync_meta_repository.dart';
import '../../../utils/app_logger.dart';
import '../../state/sync_state.dart';
import 'control_doc.dart';
import 'device_identity.dart';
import 'firestore_gateway.dart';
import 'sync_backfill_service.dart';
import 'sync_config.dart';
import 'sync_control_service.dart';
import 'sync_keys.dart';

enum EnableOutcome {
  success,
  notSignedIn,

  /// Tried to enable as primary while another device already holds the writer
  /// role — the user should use the handoff / force-takeover flow instead.
  otherDeviceIsPrimary,

  /// The control epoch moved during the claim — re-read and retry.
  raced,

  /// The rollback snapshot could not be taken; nothing was changed/published.
  snapshotFailed,

  /// The cloud (Firestore) couldn't be reached — transient network/service
  /// error. Nothing was changed locally; the user can simply retry.
  unavailable,
}

/// Turns multi-device sync on / off for this device and drives the initial
/// role adoption. The actual workers (pump / applier) are started reactively by
/// [SyncCoordinator] when [SyncState.refresh] recomputes the role.
class SyncEnableService {
  SyncEnableService._();

  /// Make this the primary (writer): persist the flag + device name, claim the
  /// writer role (only if the account is unclaimed or already this device), then
  /// backfill every existing row to the cloud behind a fresh rollback snapshot.
  static Future<EnableOutcome> enableAsPrimary({
    required FirestoreGateway gateway,
    required SyncMetaRepository meta,
    required SyncState syncState,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required Future<void> Function() drain,
    required Future<bool> Function() ensureRollbackSnapshot,
    required String deviceName,
    void Function(int done, int total)? onBackfillProgress,
  }) async {
    final uid = syncState.currentUid;
    if (uid == null) return EnableOutcome.notSignedIn;

    final deviceId =
        syncState.myDeviceId ?? await DeviceIdentity.deviceId(meta);

    // Do every cloud read/claim first and behind a try/catch, so a network or
    // Firestore-service failure leaves local state completely untouched — we
    // never half-enable (flag flipped on but the writer role never claimed).
    try {
      final control = await gateway.readControl(uid);
      if (control != null && control.writerDeviceId != deviceId) {
        return EnableOutcome.otherDeviceIsPrimary;
      }
      // Claim only when the account has never had a writer. If it already names
      // this device, we're re-affirming — no epoch bump needed.
      if (control == null) {
        await SyncControlService.claimWriter(
          gateway: gateway,
          uid: uid,
          deviceName: deviceName,
          deviceId: deviceId,
          expectedEpoch: 0,
        );
      }
    } on StateError {
      return EnableOutcome.raced;
    } catch (e) {
      AppLogger.warning('[SyncEnable] enableAsPrimary cloud op failed: $e');
      return EnableOutcome.unavailable;
    }

    // Cloud claim confirmed — only now commit local state and publish.
    await DeviceIdentity.setDeviceName(meta, deviceName);
    await meta.set(SyncMetaKeys.syncEnabled, '1');
    SyncConfig.setEnabled(true);

    // Role → writer → coordinator starts the pump.
    await syncState.refresh();

    final backfill = SyncBackfillService(
      customerRepo: customerRepo,
      orderRepo: orderRepo,
      measurementRepo: measurementRepo,
      metaRepo: meta,
      ensureRollbackSnapshot: ensureRollbackSnapshot,
      drain: drain,
    );
    final result = await backfill.run(onProgress: onBackfillProgress);
    if (result.status == BackfillStatus.snapshotFailed) {
      return EnableOutcome.snapshotFailed;
    }

    AppLogger.info('[SyncEnable] Enabled as primary "$deviceName".');
    return EnableOutcome.success;
  }

  /// Break-glass "make this the primary" for when the cloud control doc still
  /// names a device that is gone (lost / sold / reset / **reinstalled** — a
  /// fresh install mints a new device id, so the same physical device no longer
  /// matches its old claim). [enableAsPrimary] correctly refuses in that case;
  /// this is the explicit, user-confirmed override.
  ///
  /// Order is deliberate: rollback snapshot FIRST, then force-claim the writer
  /// role (no epoch guard — the named primary won't contest it), commit local
  /// state, then republish every local row so the cloud reflects this device's
  /// data. We reset `backfill_done` so the publish always runs, even on a device
  /// that had published before.
  static Future<EnableOutcome> forceEnableAsPrimary({
    required FirestoreGateway gateway,
    required SyncMetaRepository meta,
    required SyncState syncState,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required Future<void> Function() drain,
    required Future<bool> Function() ensureRollbackSnapshot,
    required String deviceName,
    void Function(int done, int total)? onBackfillProgress,
  }) async {
    final uid = syncState.currentUid;
    if (uid == null) return EnableOutcome.notSignedIn;

    final deviceId =
        syncState.myDeviceId ?? await DeviceIdentity.deviceId(meta);

    // The one rollback artifact for the whole operation — taken before we touch
    // the cloud claim. If it fails, nothing changes.
    if (!await ensureRollbackSnapshot()) return EnableOutcome.snapshotFailed;

    try {
      await SyncControlService.forceTakeover(
        gateway: gateway,
        uid: uid,
        deviceId: deviceId,
        deviceName: deviceName,
      );
    } catch (e) {
      AppLogger.warning('[SyncEnable] forceEnableAsPrimary cloud op failed: $e');
      return EnableOutcome.unavailable;
    }

    await DeviceIdentity.setDeviceName(meta, deviceName);
    await meta.set(SyncMetaKeys.syncEnabled, '1');
    SyncConfig.setEnabled(true);
    // Force a republish even if this device had backfilled before.
    await meta.set(SyncMetaKeys.backfillDone, '0');

    // Role → writer → coordinator starts the pump.
    await syncState.refresh();

    final backfill = SyncBackfillService(
      customerRepo: customerRepo,
      orderRepo: orderRepo,
      measurementRepo: measurementRepo,
      metaRepo: meta,
      // The rollback snapshot was already taken above; don't take a second one.
      ensureRollbackSnapshot: () async => true,
      drain: drain,
    );
    final result = await backfill.run(onProgress: onBackfillProgress);
    if (result.status == BackfillStatus.snapshotFailed) {
      return EnableOutcome.snapshotFailed;
    }

    AppLogger.warning('[SyncEnable] Force-enabled as primary "$deviceName".');
    return EnableOutcome.success;
  }

  /// Adopt reader (mirror) mode. Takes a rollback snapshot first because the
  /// applier's reconcile will replace this device's local data with the cloud
  /// mirror. The caller should already have confirmed with the user.
  static Future<EnableOutcome> enableAsReader({
    required SyncMetaRepository meta,
    required SyncState syncState,
    required Future<bool> Function() ensureRollbackSnapshot,
    String? deviceName,
  }) async {
    final uid = syncState.currentUid;
    if (uid == null) return EnableOutcome.notSignedIn;

    if (!await ensureRollbackSnapshot()) return EnableOutcome.snapshotFailed;

    if (deviceName != null && deviceName.isNotEmpty) {
      await DeviceIdentity.setDeviceName(meta, deviceName);
    }
    await meta.set(SyncMetaKeys.syncEnabled, '1');
    SyncConfig.setEnabled(true);

    // Role → reader (a primary exists) → coordinator starts the applier, whose
    // first-snapshot reconcile converges this device to the mirror.
    await syncState.refresh();
    AppLogger.info('[SyncEnable] Enabled as reader.');
    return EnableOutcome.success;
  }

  /// Turn sync off on this device. Leaves the cloud control doc intact (other
  /// devices keep syncing); this device reverts to full local-only behaviour.
  static Future<void> disable({
    required SyncMetaRepository meta,
    required SyncState syncState,
  }) async {
    await meta.set(SyncMetaKeys.syncEnabled, '0');
    SyncConfig.setEnabled(false);
    await syncState.refresh();
    AppLogger.info('[SyncEnable] Sync disabled on this device.');
  }

  /// Whether the account already has a primary (used to choose the right UI:
  /// "Enable as primary" for a fresh account vs "Mirror this device" otherwise).
  static Future<ControlDoc?> currentControl({
    required FirestoreGateway gateway,
    required String uid,
  }) =>
      gateway.readControl(uid);
}
