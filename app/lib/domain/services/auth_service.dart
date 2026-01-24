import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive/hive.dart';
import '../../config/auth_config.dart';
import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
import 'onboarding_service.dart';

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

  static Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      return true;
    } catch (e) {
      AppLogger.error('signInWithGoogle failed', e);
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      final userId = _auth.currentUser?.uid;

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      await _clearLocalDatabases();

      if (userId != null) {
        await OnboardingService.clearBackupChoice(userId);
      }
    } catch (e) {
      AppLogger.error('signOut failed', e);
      rethrow;
    }
  }

  static Future<void> _clearLocalDatabases() async {
    try {
      final customersBox = Hive.box<Customer>('customers_box');
      final ordersBox = Hive.box<Order>('orders_box');
      final settingsBox = Hive.box<AppSettings>('settings_box');

      await customersBox.clear();
      await ordersBox.clear();
      await settingsBox.clear();
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

