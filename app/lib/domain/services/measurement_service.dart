import '../../backend/models/measurement.dart';
import '../../backend/repositories/measurement_repository.dart';
import '../state/measurement_state.dart';

class MeasurementService {
  static Future<void> loadMeasurements(
    MeasurementState state,
    MeasurementRepository repository,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      final measurements = await repository.getAllMeasurements();
      state.setMeasurements(measurements);
    } catch (e) {
      state.setError('Failed to load measurements: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> loadMeasurementsByCustomerId(
    MeasurementState state,
    MeasurementRepository repository,
    String customerId,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      final measurements = await repository.getMeasurementsByCustomerId(customerId);
      state.setMeasurements(measurements);
    } catch (e) {
      state.setError('Failed to load measurements: $e');
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> addMeasurement(
    MeasurementState state,
    MeasurementRepository repository,
    Measurement measurement,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.addMeasurement(measurement);
      state.addMeasurement(measurement);
    } catch (e) {
      state.setError('Failed to add measurement: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> updateMeasurement(
    MeasurementState state,
    MeasurementRepository repository,
    Measurement measurement,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.updateMeasurement(measurement);
      state.updateMeasurement(measurement);
    } catch (e) {
      state.setError('Failed to update measurement: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }

  static Future<void> deleteMeasurement(
    MeasurementState state,
    MeasurementRepository repository,
    String id,
  ) async {
    state.setLoading(true);
    state.clearError();

    try {
      await repository.deleteMeasurement(id);
      state.removeMeasurement(id);
    } catch (e) {
      state.setError('Failed to delete measurement: $e');
      rethrow;
    } finally {
      state.setLoading(false);
    }
  }
}

