import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import '../../config/auth_config.dart';
import '../../backend/backend.dart';
import '../../utils/app_logger.dart';
import 'auto_backup_service.dart';
import 'notification_service.dart';
import 'onboarding_service.dart';
import 'pending_orders_reminder_service.dart';
import 'sync/media_hydration_service.dart';
import 'sync/restore_media_state.dart';
import 'sync/sync_coordinator.dart';

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

  static Future<void> signOut({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
    required SettingsRepository settingsRepository,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;

      // Stop any in-flight restore media download FIRST, so it can't keep
      // repopulating the files we're about to delete, fetch the previous
      // account's media, or starve this sign-out by saturating the isolate.
      // Clearing the flag also stops a relaunch from resuming it.
      MediaHydrationService.cancel();
      await RestoreMediaState.clearPending();

      // Tear down sync workers + the live Firestore control listener before we
      // clear Firebase auth and wipe the DB. Otherwise the listener fires
      // permission-denied mid-wipe and an in-flight push-pump drain races the
      // database clear — both of which made sign-out slow and noisy.
      await SyncCoordinator.instance?.stopForSignOut();

      // Firebase sign-out flips the auth stream → the app returns to login, so
      // it must run; bound it so a stuck call can't hang sign-out forever.
      await _auth.signOut().timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            AppLogger.warning('signOut: FirebaseAuth.signOut timed out'),
      );

      // Google session disconnect is best-effort and not required for the app's
      // auth state; it can hang on poor connectivity, so never let it block.
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 5));
      } catch (e) {
        AppLogger.warning('signOut: GoogleSignIn.signOut skipped ($e)');
      }

      await Future.wait([
        _clearLocalDatabases(
          customerRepository: customerRepository,
          orderRepository: orderRepository,
          measurementRepository: measurementRepository,
          settingsRepository: settingsRepository,
        ),
        _clearLocalFiles(),
        AutoBackupService.cancelAutoBackup(),
        PendingOrdersReminderService.cancelReminder(),
        NotificationService.cancelAllNotifications(),
      ]);

      if (userId != null) {
        await OnboardingService.clearBackupChoice(userId);
      }
    } catch (e) {
      AppLogger.error('signOut failed', e);
      rethrow;
    }
  }

  static Future<void> _clearLocalDatabases({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    required MeasurementRepository measurementRepository,
    required SettingsRepository settingsRepository,
  }) async {
    try {
      await SqliteDatabase.withForeignKeysDisabled(() async {
        // Clear children first, then parents
        await Future.wait([
          orderRepository.clearAll(),
          measurementRepository.clearAll(),
          settingsRepository.clearAll(),
        ]);
        await customerRepository.clearAll();
      });
    } catch (e) {
      AppLogger.error('Error clearing databases', e);
      rethrow;
    }
  }

  static Future<void> _clearLocalFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();

      // Delete order images folder
      final imagesDir = Directory('${appDir.path}/order_images');
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
        AppLogger.info('Deleted order_images directory');
      }

      // Delete measurement audio files
      final files = appDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.m4a')) {
          await file.delete();
          AppLogger.info('Deleted audio file: ${file.path}');
        }
      }
    } catch (e) {
      AppLogger.error('Error clearing local files', e);
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
