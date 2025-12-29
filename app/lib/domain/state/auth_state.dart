import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthState extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  bool _pendingBackupCheck = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get pendingBackupCheck => _pendingBackupCheck;

  String? get userEmail => _user?.email;
  String? get userName => _user?.displayName;
  String? get userPhotoUrl => _user?.photoURL;

  void setUser(User? user) {
    _user = user;
    _errorMessage = null;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setPendingBackupCheck({required bool pending}) {
    _pendingBackupCheck = pending;
    notifyListeners();
  }

  void clearBackupCheck() {
    _pendingBackupCheck = false;
    notifyListeners();
  }

  void signOut() {
    _user = null;
    _errorMessage = null;
    _isLoading = false;
    _pendingBackupCheck = false;
    notifyListeners();
  }
}

