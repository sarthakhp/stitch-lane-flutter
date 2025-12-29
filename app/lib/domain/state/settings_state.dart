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
  bool get pendingOrdersReminderEnabled => _settings.pendingOrdersReminderEnabled;
  String get pendingOrdersReminderTime => _settings.pendingOrdersReminderTime;
  bool get autoBackupEnabled => _settings.autoBackupEnabled;
  String get autoBackupTime => _settings.autoBackupTime;
  DateTime? get lastBackupTime => _settings.lastBackupTime;

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

  void reset() {
    _settings = AppSettings();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

