import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../backend/repositories/sync_meta_repository.dart';
import '../../../backend/repositories/sync_outbox.dart';
import '../../../utils/app_logger.dart';
import 'sync_keys.dart';

enum BackfillStatus {
  /// Every existing row was enqueued and pushed; `backfill_done` is now set.
  success,

  /// Already completed on a prior run — nothing to do (idempotent guard).
  alreadyDone,

  /// The rollback snapshot could not be taken; nothing was published.
  snapshotFailed,
}

class BackfillResult {
  final BackfillStatus status;
  final int published;

  const BackfillResult(this.status, [this.published = 0]);
}

/// One-time publish of all existing local rows when this device becomes the
/// primary (writer). Run explicitly from the "Enable as primary" action — never
/// automatically.
///
/// Order of operations is deliberate: a fresh **rollback snapshot first** (abort
/// if it fails — we never publish without an escape hatch), then enqueue every
/// row as an `upsert`, then drain to the cloud, then mark done. Idempotent: the
/// `backfill_done` flag stops it re-running, and re-enqueuing + re-pushing is
/// harmless (`set` by id) if it ever is forced again.
class SyncBackfillService {
  final CustomerRepository _customerRepo;
  final OrderRepository _orderRepo;
  final MeasurementRepository _measurementRepo;
  final SyncMetaRepository _metaRepo;

  /// Takes a fresh rollback artifact (DB snapshot / Drive backup). Returns
  /// false on failure, which aborts the backfill before anything is published.
  final Future<bool> Function() _ensureRollbackSnapshot;

  /// Drains the outbox to the cloud to completion (the writer push pump).
  final Future<void> Function() _drain;

  SyncBackfillService({
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
    required SyncMetaRepository metaRepo,
    required Future<bool> Function() ensureRollbackSnapshot,
    required Future<void> Function() drain,
  })  : _customerRepo = customerRepo,
        _orderRepo = orderRepo,
        _measurementRepo = measurementRepo,
        _metaRepo = metaRepo,
        _ensureRollbackSnapshot = ensureRollbackSnapshot,
        _drain = drain;

  static Future<bool> isDone(SyncMetaRepository meta) async =>
      (await meta.get(SyncMetaKeys.backfillDone)) == '1';

  Future<BackfillResult> run({
    void Function(int done, int total)? onProgress,
  }) async {
    if (await isDone(_metaRepo)) {
      return const BackfillResult(BackfillStatus.alreadyDone);
    }

    AppLogger.info('[SyncBackfill] Taking rollback snapshot before publish.');
    if (!await _ensureRollbackSnapshot()) {
      AppLogger.error('[SyncBackfill] Rollback snapshot failed — aborting.');
      return const BackfillResult(BackfillStatus.snapshotFailed);
    }

    // Enumerate every synced row up front so progress has a stable total.
    final customers = await _customerRepo.getAllCustomers();
    final orders = await _orderRepo.getAllOrders();
    final measurements = await _measurementRepo.getAllMeasurements();

    final entries = <(String, String)>[
      for (final c in customers) (SyncCollections.customers, c.id),
      for (final o in orders) (SyncCollections.orders, o.id),
      for (final m in measurements) (SyncCollections.measurements, m.id),
    ];

    final total = entries.length;
    AppLogger.info('[SyncBackfill] Enqueuing $total rows for publish.');
    var done = 0;
    for (final (collection, id) in entries) {
      await SyncOutbox.enqueueForBackfill(collection, id);
      onProgress?.call(++done, total);
    }

    AppLogger.info('[SyncBackfill] Draining $total rows to cloud.');
    await _drain();

    await _metaRepo.set(SyncMetaKeys.backfillDone, '1');
    AppLogger.info('[SyncBackfill] Complete ($total rows).');
    return BackfillResult(BackfillStatus.success, total);
  }
}
