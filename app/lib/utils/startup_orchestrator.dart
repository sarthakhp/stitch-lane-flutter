import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../domain/services/ai_gateway/ai_kill_switch.dart';
import '../domain/services/auth_service.dart';
import '../domain/services/notification_service.dart';
import '../firebase_options.dart';
import 'app_logger.dart';
import 'startup_tracker.dart';

/// Runs all non-critical init tasks in the background after [runApp] returns,
/// so the first frame paints without waiting for Firebase / notifications.
///
/// Consumers await [firebaseReady] before touching Firebase APIs.
class StartupOrchestrator {
  StartupOrchestrator._();
  static final StartupOrchestrator instance = StartupOrchestrator._();

  /// Completes once Firebase.initializeApp + AuthService.initializeAuthPersistence
  /// are both done. AppRoot awaits this before rendering the real auth-gated UI.
  late final Future<void> firebaseReady;

  /// Completes once NotificationService.initialize is done.
  /// MainShellScreen awaits this before calling NotificationRouter.
  late final Future<void> notificationsReady;

  /// Call once, immediately after runApp(). Returns immediately.
  void kickoff() {
    StartupTracker.instance.mark('orchestrator_kickoff');
    firebaseReady = _initFirebase();
    notificationsReady = _initNotifications();
  }

  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      StartupTracker.instance.mark('firebase_initialized');

      // Route uncaught Flutter/Dart errors to Crashlytics. Debug builds skip
      // reporting (kept local in the console) so local dev noise never
      // pollutes production crash data.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        return true;
      };
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      StartupTracker.instance.mark('crashlytics_initialized');

      await AuthService.initializeAuthPersistence();
      StartupTracker.instance.mark('auth_persistence_ready');

      // Start listening for the remote AI kill switch. Fails open (AI stays
      // enabled) if this never fires or errors — see AiKillSwitch.
      AiKillSwitch.listen();
    } catch (e) {
      AppLogger.error('StartupOrchestrator: Firebase init failed', e);
      rethrow;
    }
  }

  Future<void> _initNotifications() async {
    // Wait for Firebase first — NotificationService may need it.
    await firebaseReady;
    try {
      await NotificationService.initialize();
      StartupTracker.instance.mark('notifications_initialized');
    } catch (e) {
      AppLogger.error('StartupOrchestrator: Notifications init failed', e);
      // Non-fatal — don't rethrow. App works without notifications.
    }
  }

  /// Convenience: stream of Firebase auth state changes, available only after
  /// [firebaseReady] completes (callers must await it first).
  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();
}
