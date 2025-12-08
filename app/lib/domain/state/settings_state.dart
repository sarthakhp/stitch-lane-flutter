import 'package:flutter/foundation.dart';
import '../../backend/models/app_settings.dart';

class SettingsState extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  bool _isLoading = false;
  String? _error;

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get dueDateWarningThreshold => _settings.dueDateWarningThreshold;

  void setSettings(AppSettings settings) {
    _settings = settings;
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
}

