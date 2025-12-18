import 'package:flutter/foundation.dart';
import '../services/drive_service.dart';

class BackupState extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  BackupInfo? _backupInfo;
  double _progress = 0.0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  BackupInfo? get backupInfo => _backupInfo;
  double get progress => _progress;

  bool get hasBackup => _backupInfo != null;

  void setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
      _progress = 0.0;
    }
    notifyListeners();
  }

  void setProgress(double progress) {
    _progress = progress;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    _isLoading = false;
    _progress = 0.0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setBackupInfo(BackupInfo? info) {
    _backupInfo = info;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _progress = 0.0;
    notifyListeners();
  }
}

