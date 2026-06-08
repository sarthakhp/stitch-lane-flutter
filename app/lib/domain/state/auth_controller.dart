import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
import '../services/auth_service.dart';

/// Whether the user's auth state is resolved yet, and if so, signed in or not.
///
/// [unknown] is the startup state — auth hasn't resolved (Firebase restores the
/// cached user asynchronously). It must be treated as "wait/splash", NEVER as
/// "signed out", which is the bug this controller exists to prevent.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// The single source of truth for authentication.
///
/// - One place to read state: [status] / [user] / identity getters.
/// - One place to sign in: [signIn].
/// - One place to sign out: [signOut] (the only caller of [AuthService.signOut]).
///
/// State is derived from a single auth stream; everything else delegates here.
class AuthController extends ChangeNotifier {
  /// [authStream] is injectable for tests; defaults to Firebase's stream.
  AuthController({Stream<User?>? authStream})
      : _authStream = authStream ?? AuthService.authStateChanges();

  final Stream<User?> _authStream;
  StreamSubscription<User?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get uid => _user?.uid;
  String? get email => _user?.email;
  String? get name => _user?.displayName;
  String? get photoUrl => _user?.photoURL;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Subscribes to auth changes. Idempotent — call once, after Firebase is
  /// initialized (the stream can't be read before that).
  void init() {
    if (_sub != null) return;
    _sub = _authStream.listen(_onAuthEvent);
  }

  void _onAuthEvent(User? user) {
    _user = user;
    _status =
        user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    AppLogger.info('AuthController: status=$_status uid=${user?.uid}');
    notifyListeners();
  }

  /// Interactive Google sign-in. Status flips to authenticated via the stream;
  /// this just manages the button's loading/error state.
  Future<bool> signIn() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final ok = await AuthService.signInWithGoogle();
      _setLoading(false);
      return ok;
    } catch (e) {
      AppLogger.error('AuthController.signIn failed', e);
      _errorMessage = 'Sign-in failed. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  /// The ONLY place that signs out + wipes local data. Status flips to
  /// unauthenticated via the stream once Firebase emits.
  Future<void> signOut({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
    required SettingsRepository settingsRepository,
  }) async {
    await AuthService.signOut(
      customerRepository: customerRepository,
      orderRepository: orderRepository,
      measurementRepository: measurementRepository,
      settingsRepository: settingsRepository,
    );
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
