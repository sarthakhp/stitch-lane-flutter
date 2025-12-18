import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import '../../config/auth_config.dart';
import '../../backend/backend.dart';
import '../state/auth_state.dart';
import '../../utils/app_logger.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AuthConfig.googleClientId,
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  static GoogleSignIn get googleSignIn => _googleSignIn;

  static Future<void> initializeAuthPersistence() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
  }

  static Future<void> silentSignIn() async {
    if (kIsWeb) return;

    try {
      await _googleSignIn.signInSilently();
    } catch (e) {
      AppLogger.warning('Silent sign-in failed: $e');
    }
  }

  static Future<void> signInWithGoogle(AuthState authState) async {
    try {
      authState.setLoading(true);
      authState.clearError();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        authState.setLoading(false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      authState.setUser(userCredential.user);
      authState.setLoading(false);
    } catch (e) {
      authState.setError('Failed to sign in with Google: ${e.toString()}');
    }
  }

  static Future<void> signOut(AuthState authState) async {
    try {
      authState.setLoading(true);
      authState.clearError();

      AppLogger.info('Signing out and clearing local data...');

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      await _clearLocalDatabases();

      authState.signOut();
      AppLogger.info('Sign out complete');
    } catch (e) {
      authState.setError('Failed to sign out: ${e.toString()}');
    }
  }

  static Future<void> _clearLocalDatabases() async {
    try {
      AppLogger.info('Clearing Hive databases...');

      final customersBox = Hive.box<Customer>('customers_box');
      final ordersBox = Hive.box<Order>('orders_box');
      final settingsBox = Hive.box<AppSettings>('settings_box');

      await customersBox.clear();
      await ordersBox.clear();
      await settingsBox.clear();

      AppLogger.info('Local databases cleared');
    } catch (e) {
      AppLogger.error('Error clearing databases', e);
      rethrow;
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}

