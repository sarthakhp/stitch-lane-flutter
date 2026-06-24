import '../models/measurement_field.dart';

abstract class MeasurementFieldRepository {
  Future<List<MeasurementField>> getAll();
  Future<void> add(MeasurementField field);
  Future<void> update(MeasurementField field);
  Future<void> delete(String id);
  Future<void> replaceAll(List<MeasurementField> fields);
  Future<void> clearAll();
}
