import 'dart:async';

import '../../../backend/database/sqlite_database.dart';
import '../../../backend/models/customer.dart';
import '../../../backend/models/measurement.dart';
import '../../../backend/models/order.dart';
import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../backend/repositories/sync_meta_repository.dart';
import '../../../utils/app_logger.dart';
import '../../state/customer_state.dart';
import '../../state/measurement_state.dart';
import '../../state/order_state.dart';
import '../customer_service.dart';
import '../measurement_service.dart';
import '../order_service.dart';
import 'doc_change.dart';
import 'firestore_gateway.dart';
import 'sync_keys.dart';

/// Mirrors the cloud into the local DB on a reader device.
///
/// For each synced collection it subscribes to [FirestoreGateway.watchCollection]
/// and applies the change stream through the repos' sync-only write path (which
/// never enqueues to the outbox, so the mirror can't become dirty). After each
/// batch it refreshes the matching `*State` via the same loader the app uses at
/// startup, so the read-only UI updates live.
///
/// The applier is the ONLY writer to a reader's DB.
class SyncApplier {
  final FirestoreGateway _gateway;
  final SyncMetaRepository _metaRepo;
  final String? Function() _uid;
  final List<_CollectionMirror> _mirrors;

  final List<StreamSubscription<List<DocChange>>> _subs = [];
  final Set<String> _bootstrapped = {};

  /// Completes once the first snapshot of EVERY synced collection has applied,
  /// so a reader can hold a loading screen until its mirror is usable.
  final Completer<void> _ready = Completer<void>();

  /// Resolves when the initial mirror is fully populated (see [_ready]).
  Future<void> get bootstrapped => _ready.future;

  /// Serializes batch application across the three collection streams. The
  /// mirror writes toggle the connection-wide foreign-keys pragma off (so a doc
  /// can arrive before its parent without tripping a constraint), which is only
  /// safe if no two batches are mid-flight at once.
  Future<void> _chain = Future<void>.value();

  bool _disposed = false;

  SyncApplier({
    required FirestoreGateway gateway,
    required SyncMetaRepository metaRepo,
    required String? Function() uid,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required CustomerState customerState,
    required OrderState orderState,
    required MeasurementState measurementState,
  })  : _gateway = gateway,
        _metaRepo = metaRepo,
        _uid = uid,
        _mirrors = [
          _CollectionMirror(
            collection: SyncCollections.customers,
            applyUpsert: (data) =>
                customerRepo.upsertFromSync(Customer.fromJson(data)),
            applyDelete: customerRepo.deleteFromSync,
            reconcileKeep: customerRepo.deleteAllExcept,
            refreshState: () =>
                CustomerService.loadCustomers(customerState, customerRepo),
          ),
          _CollectionMirror(
            collection: SyncCollections.orders,
            applyUpsert: (data) => orderRepo.upsertFromSync(Order.fromJson(data)),
            applyDelete: orderRepo.deleteFromSync,
            reconcileKeep: orderRepo.deleteAllExcept,
            refreshState: () => OrderService.loadOrders(orderState, orderRepo),
          ),
          _CollectionMirror(
            collection: SyncCollections.measurements,
            applyUpsert: (data) =>
                measurementRepo.upsertFromSync(Measurement.fromJson(data)),
            applyDelete: measurementRepo.deleteFromSync,
            reconcileKeep: measurementRepo.deleteAllExcept,
            refreshState: () => MeasurementService.loadMeasurements(
                measurementState, measurementRepo),
          ),
        ];

  /// Subscribes to every synced collection. No-op when signed out.
  void start() {
    final uid = _uid();
    if (uid == null || _disposed) return;
    for (final mirror in _mirrors) {
      final sub = _gateway.watchCollection(uid, mirror.collection).listen(
        (changes) => _enqueue(mirror, changes),
        onError: (Object e) =>
            AppLogger.warning('[SyncApplier] ${mirror.collection} stream: $e'),
      );
      _subs.add(sub);
    }
  }

  void _enqueue(_CollectionMirror mirror, List<DocChange> changes) {
    _chain = _chain.then((_) => _apply(mirror, changes)).catchError(
      (Object e) {
        AppLogger.warning('[SyncApplier] apply ${mirror.collection} failed: $e');
      },
    );
  }

  Future<void> _apply(_CollectionMirror mirror, List<DocChange> changes) async {
    if (_disposed) return;
    final firstAttach = !_bootstrapped.contains(mirror.collection);

    await SqliteDatabase.withForeignKeysDisabled(() async {
      for (final change in changes) {
        switch (change.kind) {
          case DocChangeKind.added:
          case DocChangeKind.modified:
            final data = change.data;
            if (data == null) break;
            try {
              await mirror.applyUpsert(data);
            } catch (e) {
              AppLogger.warning(
                  '[SyncApplier] ${mirror.collection}/${change.id} upsert: $e');
            }
            break;
          case DocChangeKind.removed:
            try {
              await mirror.applyDelete(change.id);
            } catch (e) {
              AppLogger.warning(
                  '[SyncApplier] ${mirror.collection}/${change.id} delete: $e');
            }
            break;
        }
      }

      // The first emission is the full snapshot (gateway contract), so any
      // local row absent from it was deleted in the cloud while this device's
      // mirror was offline — drop it.
      if (firstAttach) {
        final keep = changes
            .where((c) => c.kind != DocChangeKind.removed)
            .map((c) => c.id)
            .toSet();
        final removed = await mirror.reconcileKeep(keep);
        if (removed > 0) {
          AppLogger.info(
              '[SyncApplier] ${mirror.collection}: reconcile dropped $removed stale row(s)');
        }
      }
    });

    if (firstAttach) {
      _bootstrapped.add(mirror.collection);
      if (_bootstrapped.length == _mirrors.length && !_ready.isCompleted) {
        _ready.complete();
      }
    }
    await _metaRepo.set(SyncMetaKeys.lastPullAt, DateTime.now().toIso8601String());
    await mirror.refreshState();
  }

  /// Test/diagnostic hook: completes when all queued batches have applied.
  Future<void> settle() => _chain;

  Future<void> stop() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    _bootstrapped.clear();
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}

/// Per-collection wiring: how to parse + write a doc, delete one, reconcile the
/// table to a keep-set, and refresh the matching UI state.
class _CollectionMirror {
  final String collection;
  final Future<void> Function(Map<String, dynamic> data) applyUpsert;
  final Future<void> Function(String id) applyDelete;
  final Future<int> Function(Iterable<String> keepIds) reconcileKeep;
  final Future<void> Function() refreshState;

  _CollectionMirror({
    required this.collection,
    required this.applyUpsert,
    required this.applyDelete,
    required this.reconcileKeep,
    required this.refreshState,
  });
}
