import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
import '../services/auth_service.dart';

/// Whether the user's auth state is resolved yet, and if so, signed in or not.
///
/// [unknown] is the startup state — auth hasn't resolved. Firebase restores the
/// cached user asynchronously (observed ~2.3s on release cold starts) and emits
/// `null` first. [unknown] must be treated as "wait/splash", NEVER "signed out".
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Persists a one-bit "a user was signed in" hint, so a cold start can tell a
/// still-restoring session (wait on splash) apart from a genuine sign-out (show
/// login immediately). Injectable so tests don't touch SharedPreferences.
abstract class AuthSessionHint {
  Future<bool> read();
  Future<void> write(bool wasSignedIn);
}

class _PrefsAuthSessionHint implements AuthSessionHint {
  static const _key = 'auth_had_session';

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  @override
  Future<void> write(bool wasSignedIn) async =>
      (await SharedPreferences.getInstance()).setBool(_key, wasSignedIn);
}

/// The single source of truth for authentication.
///
/// - One place to read state: [status] / [user] / identity getters.
/// - One place to sign in: [signIn].
/// - One place to sign out: [signOut] (the only caller of [AuthService.signOut]).
///
/// State is derived from a single auth stream. The startup quirk it guards
/// against: on a cold start `authStateChanges()` can emit `null` before the
/// cached user is restored — so when a prior session is known to exist we keep
/// showing the splash instead of flashing the login screen.
class AuthController extends ChangeNotifier {
  /// [authStream] / [sessionHint] are injectable for tests.
  AuthController({
    Stream<User?>? authStream,
    AuthSessionHint? sessionHint,
    this.restoreGrace = const Duration(seconds: 8),
  })  : _authStream = authStream ?? AuthService.authStateChanges(),
        _hint = sessionHint ?? _PrefsAuthSessionHint();

  final Stream<User?> _authStream;
  final AuthSessionHint _hint;

  /// Safety net: if a prior session is expected but no user is restored within
  /// this window, fall back to the login screen instead of waiting forever.
  final Duration restoreGrace;

  StreamSubscription<User?>? _sub;
  Timer? _restoreTimer;

  /// Whether we've made a real auth decision this run (vs. still restoring).
  bool _resolved = false;

  /// Persisted hint loaded in [init]: was a user signed in last time?
  bool _hadSession = false;

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
  Future<void> init() async {
    if (_sub != null) return;
    _hadSession = await _hint.read();
    // authStateChanges re-emits the current state to new listeners, so a late
    // subscription (after the hint read) still receives the initial value.
    _sub = _authStream.listen(_onAuthEvent);
  }

  void _onAuthEvent(User? user) {
    if (user != null) {
      _restoreTimer?.cancel();
      _resolved = true;
      _user = user;
      _status = AuthStatus.authenticated;
      _hint.write(true);
      AppLogger.info('AuthController: authenticated uid=${user.uid}');
      notifyListeners();
      return;
    }

    // user == null
    if (!_resolved && _hadSession) {
      // Cold start with a prior session: Firebase is likely still restoring the
      // cached user. Stay on splash (unknown) rather than flashing login; fall
      // back to login only if nothing arrives within [restoreGrace].
      AppLogger.info(
          'AuthController: null at startup with prior session — awaiting restore');
      _restoreTimer ??= Timer(restoreGrace, () {
        if (_resolved) return;
        _resolved = true;
        _status = AuthStatus.unauthenticated;
        _hint.write(false);
        AppLogger.warning('AuthController: restore timed out — showing login');
        notifyListeners();
      });
      return; // remain unknown
    }

    // Genuine sign-out, or a null after we'd already resolved → show login.
    _restoreTimer?.cancel();
    _resolved = true;
    _user = null;
    _status = AuthStatus.unauthenticated;
    _hint.write(false);
    AppLogger.info('AuthController: unauthenticated');
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
    _restoreTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
