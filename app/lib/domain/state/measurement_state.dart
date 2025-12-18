import 'package:flutter/foundation.dart';
import '../../backend/models/measurement.dart';

class MeasurementState extends ChangeNotifier {
  List<Measurement> _measurements = [];
  bool _isLoading = false;
  String? _error;

  List<Measurement> get measurements => List.unmodifiable(_measurements);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Measurement> getMeasurementsByCustomerId(String customerId) {
    return _measurements
        .where((measurement) => measurement.customerId == customerId)
        .toList();
  }

  Measurement? getLatestMeasurementForCustomer(String customerId) {
    final customerMeasurements = getMeasurementsByCustomerId(customerId);
    if (customerMeasurements.isEmpty) return null;
    
    customerMeasurements.sort((a, b) => b.modified.compareTo(a.modified));
    return customerMeasurements.first;
  }

  void setMeasurements(List<Measurement> measurements) {
    _measurements = measurements;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void addMeasurement(Measurement measurement) {
    _measurements.add(measurement);
    notifyListeners();
  }

  void updateMeasurement(Measurement measurement) {
    final index = _measurements.indexWhere((m) => m.id == measurement.id);
    if (index != -1) {
      _measurements[index] = measurement;
      notifyListeners();
    }
  }

  void removeMeasurement(String id) {
    _measurements.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearMeasurements() {
    _measurements = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

