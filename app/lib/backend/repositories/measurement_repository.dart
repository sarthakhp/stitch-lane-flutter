import '../models/measurement.dart';

abstract class MeasurementRepository {
  Future<List<Measurement>> getAllMeasurements();
  Future<List<Measurement>> getMeasurementsByCustomerId(String customerId);
  Future<Measurement?> getMeasurementById(String id);
  Future<void> addMeasurement(Measurement measurement);
  Future<void> updateMeasurement(Measurement measurement);
  Future<void> deleteMeasurement(String id);
  Future<void> deleteMeasurementsByCustomerId(String customerId);

  Future<void> clearAll();

  // ── reader mirror path (never enqueues to the sync outbox) ────────────────

  /// Insert-or-replace a row received from the cloud. Unlike [addMeasurement]
  /// this records no outbox intent, so a reader's mirror never becomes dirty.
  Future<void> upsertFromSync(Measurement measurement);

  /// Delete a single row received as a cloud removal. No cascade, no enqueue.
  Future<void> deleteFromSync(String id);

  /// Cold-start reconcile: drop every local row whose id is not in [keepIds].
  /// Returns the number of rows removed. Never enqueues.
  Future<int> deleteAllExcept(Iterable<String> keepIds);
}

