import 'dart:convert';

import '../../../backend/repositories/customer_repository.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import '../../../backend/repositories/sync_outbox.dart';
import '../../../backend/repositories/sync_quarantine.dart';
import '../../../utils/app_logger.dart';
import 'firestore_gateway.dart';
import 'sync_keys.dart';
import 'sync_serializer.dart';

/// The fence: stops a device that has lost the writer role from clobbering the
/// new primary.
///
/// Run by the push pump before every drain. If the cloud control doc no longer
/// names this device (another device took over) or its epoch has moved past the
/// one we claimed under, this device is **fenced**: it must not push. Every
/// pending outbox row is moved to [SyncQuarantine] with a payload snapshot, the
/// outbox is cleared, and the pump bails. The actual demotion to reader happens
/// reactively when the control-doc listener updates the role — this service is
/// only responsible for not losing the un-pushed writes.
class SyncFenceService {
  final FirestoreGateway _gateway;
  final CustomerRepository _customerRepo;
  final OrderRepository _orderRepo;
  final MeasurementRepository _measurementRepo;

  SyncFenceService({
    required FirestoreGateway gateway,
    required CustomerRepository customerRepo,
    required OrderRepository orderRepo,
    required MeasurementRepository measurementRepo,
  })  : _gateway = gateway,
        _customerRepo = customerRepo,
        _orderRepo = orderRepo,
        _measurementRepo = measurementRepo;

  /// True when this device may push. On fence, quarantines + clears the outbox
  /// first, then returns false.
  Future<bool> allowedToPush({
    required String uid,
    required String myDeviceId,
    required int myEpoch,
  }) async {
    final control = await _gateway.readControl(uid);
    // No control doc yet (account never claimed a writer) — nothing fences us.
    if (control == null) return true;

    final fenced =
        control.writerDeviceId != myDeviceId || control.epoch > myEpoch;
    if (!fenced) return true;

    final reason = control.writerDeviceName.isNotEmpty
        ? 'Set aside — "${control.writerDeviceName}" is now the primary device.'
        : 'Set aside — another device is now the primary.';
    await _quarantinePending(reason);
    return false;
  }

  Future<void> _quarantinePending(String reason) async {
    final rows = await SyncOutbox.pending();
    if (rows.isEmpty) return;

    AppLogger.warning(
        '[SyncFence] Fenced with ${rows.length} pending write(s) — quarantining.');
    for (final row in rows) {
      String? payload;
      if (row.op == SyncOutbox.opUpsert) {
        final model = await _load(row.collection, row.entityId);
        if (model != null) {
          payload = jsonEncode(SyncSerializer.docFor(model));
        }
      }
      await SyncQuarantine.add(
        collection: row.collection,
        entityId: row.entityId,
        op: row.op,
        payload: payload,
        reason: reason,
      );
    }
    await SyncOutbox.clear();
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
        return Future.value(null);
    }
  }
}
