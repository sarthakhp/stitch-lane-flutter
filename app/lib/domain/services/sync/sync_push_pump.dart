import 'dart:async';

import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../backend/repositories/sync_meta_repository.dart';
import '../../../backend/repositories/sync_outbox.dart';
import '../../../utils/app_logger.dart';
import 'firestore_gateway.dart';
import 'sync_control_service.dart';
import 'sync_keys.dart';
import 'sync_serializer.dart';

/// Drains the writer's [SyncOutbox] to Firestore.
///
/// Runs only on the writer device. A single drain reads every pending row,
/// batches upserts per collection and pushes deletes one at a time, then
/// removes each acked row. Anything that fails to push is left in the outbox
/// and retried on the next run, so the pump is the reconciliation backstop on
/// top of the Firestore SDK's own offline write queue. Every push is idempotent
/// (`set`/`delete` by id), so re-running after a crash is safe.
class SyncPushPump {
  final FirestoreGateway _gateway;
  final SyncMetaRepository _metaRepo;
  final CustomerRepository _customerRepo;
  final OrderRepository _orderRepo;
  final MeasurementRepository _measurementRepo;

  /// Current signed-in uid; null while signed out (drains no-op).
  final String? Function() _uid;

  /// Phase 7 fence hook. Returns false when this device has been fenced (a
  /// newer writer claimed the role) — the drain then bails without pushing so
  /// the quarantine path can take over. Null means "always allowed" (Phase 3).
  final Future<bool> Function()? _fenceCheck;

  static const Duration _debounce = Duration(seconds: 1);

  bool _running = false;
  bool _rerunRequested = false;
  bool _disposed = false;
  Timer? _debounceTimer;

  SyncPushPump({
    required FirestoreGateway gateway,
    required SyncMetaRepository metaRepo,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required String? Function() uid,
    Future<bool> Function()? fenceCheck,
  })  : _gateway = gateway,
        _metaRepo = metaRepo,
        _customerRepo = customerRepo,
        _orderRepo = orderRepo,
        _measurementRepo = measurementRepo,
        _uid = uid,
        _fenceCheck = fenceCheck;

  /// Debounced trigger for "after a local write". A burst of edits collapses
  /// into one drain ~1s after the last edit.
  void scheduleDrain() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, drain);
  }

  /// Runs a drain now (on writer start and on reconnect). Re-entrant calls are
  /// coalesced: if a drain is already running, one more pass is queued so work
  /// enqueued mid-drain isn't missed.
  Future<void> drain() async {
    if (_disposed) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerunRequested = false;
        await _drainOnce();
      } while (_rerunRequested && !_disposed);
    } finally {
      _running = false;
    }
  }

  Future<void> _drainOnce() async {
    final uid = _uid();
    if (uid == null) return;

    // Fence check first: a fenced device must never clobber the new writer.
    if (_fenceCheck != null && !(await _fenceCheck!())) {
      AppLogger.info('[SyncPushPump] Fenced — skipping drain.');
      return;
    }

    final rows = await SyncOutbox.pending();
    if (rows.isNotEmpty) {
      final upsertsByCollection = <String, List<OutboxRow>>{};
      final deletes = <OutboxRow>[];
      for (final row in rows) {
        if (row.op == SyncOutbox.opDelete) {
          deletes.add(row);
        } else {
          (upsertsByCollection[row.collection] ??= []).add(row);
        }
      }

      for (final entry in upsertsByCollection.entries) {
        await _pushUpserts(uid, entry.key, entry.value);
      }
      for (final row in deletes) {
        await _pushDelete(uid, row);
      }
    }

    await _metaRepo.set(SyncMetaKeys.lastPushAt, DateTime.now().toIso8601String());

    // Publish the remaining backlog so a reader can gate handoff on a drained
    // writer. Best-effort — a failure here never blocks the next drain.
    final remaining = await SyncOutbox.count();
    try {
      await SyncControlService.updatePendingCount(
        gateway: _gateway,
        uid: uid,
        count: remaining,
      );
    } catch (e) {
      AppLogger.warning('[SyncPushPump] pendingCount update failed: $e');
    }
  }

  Future<void> _pushUpserts(
      String uid, String collection, List<OutboxRow> rows) async {
    final docs = <(String, Map<String, dynamic>)>[];
    final loadedIds = <String>[];
    for (final row in rows) {
      final model = await _load(collection, row.entityId);
      if (model == null) {
        // Row vanished with no delete op queued (e.g. coalesced away). Nothing
        // to publish — drop the stale upsert intent.
        await SyncOutbox.remove(collection, row.entityId);
        continue;
      }
      docs.add((row.entityId, SyncSerializer.docFor(model)));
      loadedIds.add(row.entityId);
    }
    if (docs.isEmpty) return;
    try {
      await _gateway.upsertBatch(uid, collection, docs);
      for (final id in loadedIds) {
        await SyncOutbox.remove(collection, id);
      }
    } catch (e) {
      // Leave the rows for the next drain; idempotent on retry.
      AppLogger.warning('[SyncPushPump] upsert batch ($collection) failed: $e');
    }
  }

  Future<void> _pushDelete(String uid, OutboxRow row) async {
    try {
      await _gateway.delete(uid, row.collection, row.entityId);
      await SyncOutbox.remove(row.collection, row.entityId);
    } catch (e) {
      AppLogger.warning(
          '[SyncPushPump] delete (${row.collection}/${row.entityId}) failed: $e');
    }
  }

  Future<Object?> _load(String collection, String id) {
    switch (collection) {
      case SyncCollections.customers:
        return _customerRepo.getCustomerById(id);
      case SyncCollections.orders:
        return _orderRepo.getOrderById(id);
      case SyncCollections.measurements:
        return _measurementRepo.getMeasurementById(id);
      default:
        AppLogger.warning('[SyncPushPump] Unknown collection: $collection');
        return Future.value(null);
    }
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
  }
}
