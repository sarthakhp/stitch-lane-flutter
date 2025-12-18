import 'package:hive/hive.dart';
import '../models/measurement.dart';
import '../database/database_service.dart';
import 'measurement_repository.dart';

class HiveMeasurementRepository implements MeasurementRepository {
  Box<Measurement> get _box => DatabaseService.getMeasurementsBox();

  @override
  Future<List<Measurement>> getAllMeasurements() async {
    try {
      return _box.values.toList();
    } catch (e) {
      throw Exception('Failed to get measurements: $e');
    }
  }

  @override
  Future<List<Measurement>> getMeasurementsByCustomerId(String customerId) async {
    try {
      return _box.values
          .where((measurement) => measurement.customerId == customerId)
          .toList();
    } catch (e) {
      throw Exception('Failed to get measurements for customer: $e');
    }
  }

  @override
  Future<Measurement?> getMeasurementById(String id) async {
    try {
      return _box.values.firstWhere(
        (measurement) => measurement.id == id,
        orElse: () => throw Exception('Measurement not found'),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addMeasurement(Measurement measurement) async {
    try {
      await _box.put(measurement.id, measurement);
    } catch (e) {
      throw Exception('Failed to add measurement: $e');
    }
  }

  @override
  Future<void> updateMeasurement(Measurement measurement) async {
    try {
      if (_box.containsKey(measurement.id)) {
        await _box.put(measurement.id, measurement);
      } else {
        throw Exception('Measurement not found');
      }
    } catch (e) {
      throw Exception('Failed to update measurement: $e');
    }
  }

  @override
  Future<void> deleteMeasurement(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw Exception('Failed to delete measurement: $e');
    }
  }

  @override
  Future<void> deleteMeasurementsByCustomerId(String customerId) async {
    try {
      final measurementsToDelete = _box.values
          .where((measurement) => measurement.customerId == customerId)
          .map((measurement) => measurement.id)
          .toList();

      for (final measurementId in measurementsToDelete) {
        await _box.delete(measurementId);
      }
    } catch (e) {
      throw Exception('Failed to delete measurements for customer: $e');
    }
  }
}

