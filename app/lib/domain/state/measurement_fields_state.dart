import 'package:flutter/foundation.dart';

import '../../backend/models/measurement_field.dart';

class MeasurementFieldsState extends ChangeNotifier {
  List<MeasurementField> _fields = const [];
  bool _isLoading = false;
  String? _error;

  List<MeasurementField> get fields => _fields;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setFields(List<MeasurementField> fields) {
    _fields = List.unmodifiable(fields);
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

  void reset() {
    _fields = const [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
