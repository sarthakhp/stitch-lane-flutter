import '../../backend/models/measurement_field.dart';
import '../../backend/repositories/measurement_field_repository.dart';
import '../../backend/seed/default_measurement_fields.dart';
import '../state/measurement_fields_state.dart';

/// Service entry point for the global measurement fields list. Mirrors the
/// shape of [SettingsService] — pure static functions that mutate a passed-in
/// state and persist via the repository. Seeds defaults on first load when
/// the table is empty.
class MeasurementFieldsService {
  static Future<void> loadFields(
    MeasurementFieldsState state,
    MeasurementFieldRepository repository,
  ) async {
    state.setLoading(true);
    state.setError(null);
    try {
      var fields = await repository.getAll();
      if (fields.isEmpty) {
        fields = DefaultMeasurementFields.build();
        await repository.replaceAll(fields);
      }
      state.setFields(fields);
    } catch (e) {
      state.setError('Failed to load measurement fields: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> saveAll(
    MeasurementFieldsState state,
    MeasurementFieldRepository repository,
    List<MeasurementField> fields,
  ) async {
    state.setError(null);
    try {
      final reindexed = <MeasurementField>[
        for (var i = 0; i < fields.length; i++)
          fields[i].copyWith(sortOrder: i),
      ];
      await repository.replaceAll(reindexed);
      state.setFields(reindexed);
    } catch (e) {
      state.setError('Failed to save measurement fields: $e');
      rethrow;
    }
  }

  static Future<void> restoreDefaults(
    MeasurementFieldsState state,
    MeasurementFieldRepository repository,
  ) async {
    await saveAll(state, repository, DefaultMeasurementFields.build());
  }
}
