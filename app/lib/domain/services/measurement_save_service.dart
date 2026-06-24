import 'package:uuid/uuid.dart';

import '../../backend/backend.dart';
import '../state/measurement_state.dart';
import 'measurement_service.dart';
import 'measurement_structurer.dart';
import 'recordings/recording_metadata.dart';
import 'recordings/recording_store.dart';

/// Persists a structured measurement and links its recordings — the
/// create/update + sidecar logic, kept out of the form widget.
class MeasurementSaveService {
  MeasurementSaveService._();

  /// Saves [structured] for [customer] (creates when [existing] is null,
  /// updates otherwise), deriving `description` from the structure, then
  /// writes a recording sidecar for each path in [newAudioFilePaths]. Returns
  /// the saved measurement id.
  static Future<String> save({
    required MeasurementState state,
    required MeasurementRepository repository,
    required Customer customer,
    required Measurement? existing,
    required StructuredMeasurement structured,
    required List<String> audioFilePaths,
    required List<String> newAudioFilePaths,
    required DateTime now,
  }) async {
    final description = MeasurementStructurer.serialize(structured).trim();
    final structuredJson = structured.isEmpty ? null : structured.toJson();

    final String id;
    if (existing != null) {
      id = existing.id;
      await MeasurementService.updateMeasurement(
        state,
        repository,
        existing.copyWith(
          description: description,
          modified: now,
          audioFilePaths: audioFilePaths,
          structuredData: structuredJson,
          clearStructuredData: structuredJson == null,
        ),
      );
    } else {
      id = const Uuid().v4();
      await MeasurementService.addMeasurement(
        state,
        repository,
        Measurement(
          id: id,
          customerId: customer.id,
          description: description,
          created: now,
          modified: now,
          audioFilePaths: audioFilePaths,
          structuredData: structuredJson,
        ),
      );
    }

    await _writeSidecars(
      paths: newAudioFilePaths,
      customer: customer,
      measurementId: id,
      transcript: description,
      isEditing: existing != null,
    );
    return id;
  }

  /// Best-effort sidecar per newly-captured recording, so they surface in the
  /// Recordings debugger and survive cleanup. Never throws.
  static Future<void> _writeSidecars({
    required List<String> paths,
    required Customer customer,
    required String measurementId,
    required String transcript,
    required bool isEditing,
  }) async {
    final action = isEditing ? 'Updated measurement' : 'Saved measurement';
    for (final path in paths) {
      await RecordingStore.writeSidecar(
        path,
        RecordingMetadata(
          source: RecordingSource.measurement,
          title: customer.name,
          transcript: transcript,
          actions: ['$action for ${customer.name}'],
          customerId: customer.id,
          measurementId: measurementId,
        ),
      );
    }
  }
}
