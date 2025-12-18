import '../models/measurement.dart';

abstract class MeasurementRepository {
  Future<List<Measurement>> getAllMeasurements();
  Future<List<Measurement>> getMeasurementsByCustomerId(String customerId);
  Future<Measurement?> getMeasurementById(String id);
  Future<void> addMeasurement(Measurement measurement);
  Future<void> updateMeasurement(Measurement measurement);
  Future<void> deleteMeasurement(String id);
  Future<void> deleteMeasurementsByCustomerId(String customerId);
}

