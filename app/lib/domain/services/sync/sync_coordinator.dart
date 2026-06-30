import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../backend/repositories/sync_meta_repository.dart';
import '../../../backend/database/db_snapshot_service.dart';
import '../../../backend/repositories/sync_outbox.dart';
import '../../../utils/app_logger.dart';
import '../../state/customer_state.dart';
import '../../state/measurement_state.dart';
import '../../state/order_state.dart';
import '../../state/sync_state.dart';
import '../connectivity/connectivity_service.dart';
import 'device_identity.dart';
import 'firestore_gateway.dart';
import 'sync_applier.dart';
import 'sync_enable_service.dart';
import 'sync_fence_service.dart';
import 'sync_handoff_service.dart';
import 'sync_push_pump.dart';
import 'sync_role.dart';
import 'sync_writer_bootstrap.dart';

/// Owns the lifecycle of the sync background workers, binding them to the
/// device's current [SyncRole].
///
/// On the writer it runs a [SyncPushPump]; on a reader it runs a [SyncApplier].
/// It listens to [SyncState] for role flips and to [SyncOutbox.revision] so a
/// local write nudges the pump. Flag-off keeps the role at `unconfigured`, so
/// nothing ever starts.
class SyncCoordinator {
  final SyncState _syncState;
  final FirestoreGateway _gateway;
  final SyncMetaRepository _metaRepo;
  final CustomerRepository _customerRepo;
  final OrderRepository _orderRepo;
  final MeasurementRepository _measurementRepo;
  final CustomerState _customerState;
  final OrderState _orderState;
  final MeasurementState _measurementState;

  SyncPushPump? _pump;
  SyncApplier? _applier;
  SyncRole? _lastRole;
  bool _disposed = false;

  /// The one live coordinator, so the static sign-out path ([AuthService]) can
  /// tear sync down without threading this instance through every UI call site.
  /// There is exactly one coordinator app-wide (a Provider singleton).
  static SyncCoordinator? _instance;
  static SyncCoordinator? get instance => _instance;

  SyncCoordinator({
    required SyncState syncState,
    required FirestoreGateway gateway,
    required SyncMetaRepository metaRepo,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required CustomerState customerState,
    required OrderState orderState,
    required MeasurementState measurementState,
  })  : _syncState = syncState,
        _gateway = gateway,
        _metaRepo = metaRepo,
        _customerRepo = customerRepo,
        _orderRepo = orderRepo,
        _measurementRepo = measurementRepo,
        _customerState = customerState,
        _orderState = orderState,
        _measurementState = measurementState {
    _instance = this;
    _syncState.addListener(_onSyncStateChanged);
    SyncOutbox.revision.addListener(_onOutboxChanged);
    // Adopt the current role immediately (the role may already be writer when
    // this is constructed after a hot restart).
    _onSyncStateChanged();
  }

  void _onSyncStateChanged() {
    if (_disposed) return;
    final role = _syncState.role;
    if (role == _lastRole) return;
    _lastRole = role;
    switch (role) {
      case SyncRole.writer:
        _stopApplier();
        _startPump();
        break;
      case SyncRole.reader:
        _stopPump();
        _startApplier();
        break;
      case SyncRole.unconfigured:
        _stopPump();
        _stopApplier();
        break;
    }
  }

  void _startPump() {
    if (_pump != null) return;
    AppLogger.info('[SyncCoordinator] Becoming writer — starting push pump.');
    final fence = SyncFenceService(
      gateway: _gateway,
      customerRepo: _customerRepo,
      orderRepo: _orderRepo,
      measurementRepo: _measurementRepo,
    );
    _pump = SyncPushPump(
      gateway: _gateway,
      metaRepo: _metaRepo,
      customerRepo: _customerRepo,
      orderRepo: _orderRepo,
      measurementRepo: _measurementRepo,
      uid: () => _syncState.currentUid,
      fenceCheck: _fenceCheck(fence),
    );
    _writerColdStart();
  }

  /// Restore from cloud if this writer came up with an empty local DB (e.g.
  /// after a sign-out wiped data while the control doc still named us), THEN
  /// flush any backlog. The repull is a no-op for a normal/fresh writer.
  Future<void> _writerColdStart() async {
    final uid = _syncState.currentUid;
    if (uid != null) {
      try {
        await SyncWriterBootstrap.repullIfEmpty(
          gateway: _gateway,
          uid: uid,
          customerRepo: _customerRepo,
          orderRepo: _orderRepo,
          measurementRepo: _measurementRepo,
          customerState: _customerState,
          orderState: _orderState,
          measurementState: _measurementState,
        );
      } catch (e) {
        AppLogger.warning('[SyncCoordinator] writer cold-start repull failed: $e');
      }
    }
    await _pump?.drain();
  }

  /// Builds the pump's fence gate. Returns true (allow push) only when we have
  /// a known identity AND the cloud control doc still names this device under
  /// our epoch; otherwise the fence service quarantines pending writes and we
  /// return false so the pump bails. Unknown identity → bail without quarantine
  /// (transient; retried next drain).
  Future<bool> Function() _fenceCheck(SyncFenceService fence) {
    return () async {
      final uid = _syncState.currentUid;
      final deviceId = _syncState.myDeviceId;
      if (uid == null || deviceId == null) return false;
      return fence.allowedToPush(
        uid: uid,
        myDeviceId: deviceId,
        myEpoch: _syncState.myEpoch,
      );
    };
  }

  void _stopPump() {
    if (_pump == null) return;
    AppLogger.info('[SyncCoordinator] No longer writer — stopping push pump.');
    _pump!.dispose();
    _pump = null;
  }

  void _startApplier() {
    if (_applier != null) return;
    AppLogger.info('[SyncCoordinator] Becoming reader — starting mirror applier.');
    _applier = SyncApplier(
      gateway: _gateway,
      metaRepo: _metaRepo,
      uid: () => _syncState.currentUid,
      customerRepo: _customerRepo,
      orderRepo: _orderRepo,
      measurementRepo: _measurementRepo,
      customerState: _customerState,
      orderState: _orderState,
      measurementState: _measurementState,
    );
    _applier!.start();
  }

  void _stopApplier() {
    if (_applier == null) return;
    AppLogger.info('[SyncCoordinator] No longer reader — stopping mirror applier.');
    _applier!.dispose();
    _applier = null;
  }

  void _onOutboxChanged() {
    _pump?.scheduleDrain();
  }

  /// Force an immediate drain — call on connectivity regained so queued writes
  /// flush without waiting for the next local edit.
  void onReconnect() {
    _pump?.drain();
  }

  /// Drains the outbox to completion (awaitable). Used by the backfill flow.
  Future<void> drainNow() async => _pump?.drain();

  // ── control-plane API for the settings UI ────────────────────────────────

  Future<bool> _snapshot() async => (await DbSnapshotService.snapshotNow()) != null;

  /// Make this device the primary and publish all existing rows.
  Future<EnableOutcome> enableAsPrimary({
    required String deviceName,
    void Function(int done, int total)? onBackfillProgress,
  }) {
    return SyncEnableService.enableAsPrimary(
      gateway: _gateway,
      meta: _metaRepo,
      syncState: _syncState,
      customerRepo: _customerRepo,
      orderRepo: _orderRepo,
      measurementRepo: _measurementRepo,
      drain: drainNow,
      ensureRollbackSnapshot: _snapshot,
      deviceName: deviceName,
      onBackfillProgress: onBackfillProgress,
    );
  }

  /// Break-glass takeover from the setup screen: become the primary even though
  /// the cloud still names another (gone) device. Caller must confirm first.
  Future<EnableOutcome> forceEnableAsPrimary({
    required String deviceName,
    void Function(int done, int total)? onBackfillProgress,
  }) {
    return SyncEnableService.forceEnableAsPrimary(
      gateway: _gateway,
      meta: _metaRepo,
      syncState: _syncState,
      customerRepo: _customerRepo,
      orderRepo: _orderRepo,
      measurementRepo: _measurementRepo,
      drain: drainNow,
      ensureRollbackSnapshot: _snapshot,
      deviceName: deviceName,
      onBackfillProgress: onBackfillProgress,
    );
  }

  /// Name of the device the cloud currently records as the primary, or null if
  /// none / not signed in. Used to name the device in the takeover prompt.
  Future<String?> currentPrimaryName() async {
    final uid = _syncState.currentUid;
    if (uid == null) return null;
    final control =
        await SyncEnableService.currentControl(gateway: _gateway, uid: uid);
    return control?.writerDeviceName;
  }

  /// Mirror this device against the existing primary (replaces local data).
  Future<EnableOutcome> enableAsReader({String? deviceName}) {
    return SyncEnableService.enableAsReader(
      meta: _metaRepo,
      syncState: _syncState,
      ensureRollbackSnapshot: _snapshot,
      deviceName: deviceName,
    );
  }

  Future<void> disableSync() =>
      SyncEnableService.disable(meta: _metaRepo, syncState: _syncState);

  /// Synchronously tear down the push pump, applier, and the live Firestore
  /// control listener — called at the very start of sign-out, BEFORE Firebase
  /// auth is cleared and the local DB is wiped. Without this the control
  /// listener fires permission-denied mid-wipe and an in-flight pump drain can
  /// race the database clear. Best-effort; never throws.
  Future<void> stopForSignOut() async {
    try {
      _stopPump();
      _stopApplier();
      _lastRole = SyncRole.unconfigured;
      await _syncState.stop();
    } catch (e) {
      AppLogger.warning('[SyncCoordinator] stopForSignOut: $e');
    }
  }

  /// Normal handoff: claim the writer role from a reader (gated on online +
  /// the current writer being fully drained).
  Future<HandoffStatus> requestHandoff() async {
    final uid = _syncState.currentUid;
    final deviceId = _syncState.myDeviceId;
    if (uid == null || deviceId == null) return HandoffStatus.offline;
    final name = await DeviceIdentity.deviceName(_metaRepo);
    final status = await SyncHandoffService.handoff(
      gateway: _gateway,
      uid: uid,
      deviceId: deviceId,
      deviceName: name,
      isOnline: ConnectivityService.instance.hasInternet,
    );
    if (status == HandoffStatus.success) await _syncState.refresh();
    return status;
  }

  /// Break-glass takeover for a lost/broken primary. Caller must confirm first.
  Future<HandoffStatus> requestForceTakeover() async {
    final uid = _syncState.currentUid;
    final deviceId = _syncState.myDeviceId;
    if (uid == null || deviceId == null) return HandoffStatus.offline;
    final name = await DeviceIdentity.deviceName(_metaRepo);
    final status = await SyncHandoffService.forceTakeover(
      gateway: _gateway,
      uid: uid,
      deviceId: deviceId,
      deviceName: name,
      ensureRollbackSnapshot: _snapshot,
    );
    if (status == HandoffStatus.success) await _syncState.refresh();
    return status;
  }

  void dispose() {
    _disposed = true;
    if (identical(_instance, this)) _instance = null;
    _syncState.removeListener(_onSyncStateChanged);
    SyncOutbox.revision.removeListener(_onOutboxChanged);
    _stopPump();
    _stopApplier();
  }
}
