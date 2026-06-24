import 'dart:io';

import '../../../backend/models/measurement.dart';
import '../../../backend/models/order.dart';
import '../../../backend/repositories/measurement_repository.dart';
import '../../../backend/repositories/order_repository.dart';
import 'entity_recording.dart';

/// Aggregates every voice recording belonging to a customer by unioning the
/// `audioFilePath` links on that customer's orders and measurements.
///
/// This is the customer-level view: it doesn't read the flat audio folder or
/// sidecars — it follows the authoritative DB links, so it stays correct as
/// recordings are added, edited, or cleaned up. Results are de-duplicated by
/// file path (one dictation in the order creator links the same file to
/// several orders + a measurement) and sorted newest-first.
class CustomerRecordingsService {
  CustomerRecordingsService._();

  /// Pure transform: union + de-dupe (by path) + sort (newest-first). No I/O,
  /// so it's safe to call from a reactive `build` over in-memory state. Does
  /// NOT check file existence — callers that need that should filter after.
  static List<EntityRecording> buildTimeline({
    required List<Order> orders,
    required List<Measurement> measurements,
  }) {
    final candidates = <EntityRecording>[];

    for (final o in orders) {
      final label =
          (o.title?.trim().isNotEmpty ?? false) ? o.title!.trim() : 'Order';
      for (final path in o.audioFilePaths) {
        if (path.trim().isEmpty) continue;
        candidates.add(EntityRecording(
          filePath: path,
          createdAt: o.created,
          kind: EntityRecordingKind.order,
          entityId: o.id,
          label: label,
        ));
      }
    }

    for (final m in measurements) {
      for (final path in m.audioFilePaths) {
        if (path.trim().isEmpty) continue;
        candidates.add(EntityRecording(
          filePath: path,
          createdAt: m.created,
          kind: EntityRecordingKind.measurement,
          entityId: m.id,
          label: 'Measurement',
        ));
      }
    }

    candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final seenPaths = <String>{};
    final deduped = <EntityRecording>[];
    for (final rec in candidates) {
      if (seenPaths.add(rec.filePath)) deduped.add(rec);
    }
    return deduped;
  }

  /// Repo-backed load that also drops recordings whose file is missing on
  /// disk. For non-reactive callers; reactive widgets should use
  /// [buildTimeline] over in-memory state and filter existence themselves.
  static Future<List<EntityRecording>> loadForCustomer(
    String customerId, {
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
  }) async {
    final orders = await orderRepository.getOrdersByCustomerId(customerId);
    final measurements =
        await measurementRepository.getMeasurementsByCustomerId(customerId);

    final timeline = buildTimeline(orders: orders, measurements: measurements);

    final result = <EntityRecording>[];
    for (final rec in timeline) {
      if (await File(rec.filePath).exists()) result.add(rec);
    }
    return result;
  }
}
