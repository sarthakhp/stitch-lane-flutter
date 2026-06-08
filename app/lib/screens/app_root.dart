import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';

import '../backend/backend.dart';
import '../constants/app_constants.dart';
import '../config/routes.dart';
import '../domain/domain.dart';
import '../domain/services/home_widget/home_widget_service.dart';
import '../main.dart' show navigatorKey, routeObserver;
import '../utils/app_logger.dart';
import '../utils/startup_tracker.dart';
import '../utils/startup_orchestrator.dart';
import 'home_shell_host.dart';
import 'login_screen.dart';
import 'backup_restore_check_screen.dart';
import 'widgets/app_logo.dart';

/// Top-level widget rendered by runApp. Replaces the old AppInitializer +
/// AuthGate pair. The single MaterialApp is built here; the home slot is
/// an [_AppRoot] widget that handles both the pre-Firebase loading phase and
/// auth-gating once Firebase is ready.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          // Flat app bar — no Material 3 color shift when content scrolls under.
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          // Flat app bar — no Material 3 color shift when content scrolls under.
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      themeMode: ThemeMode.system,
      // No `home:` — it can't coexist with onGenerateInitialRoutes. The
      // home-screen widget launches us with a `stitchgenie://...` data URI,
      // which the engine hands over as the platform default route name. Without
      // overriding initial-route generation, MaterialApp tries to match it as a
      // named route on cold start and shows "Route not found". We ignore the
      // initial deep link here — HomeWidgetService captures it separately and
      // dispatches it once the authenticated shell is mounted — and always boot
      // into the app root.
      onGenerateInitialRoutes: (_) =>
          [MaterialPageRoute(builder: (_) => const _AppRootHome())],
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

/// Awaits Firebase init in background, runs app-level initializations,
/// then hands off to [_AuthGate]. Shows a minimal splash while loading.
class _AppRootHome extends StatefulWidget {
  const _AppRootHome();

  @override
  State<_AppRootHome> createState() => _AppRootHomeState();
}

class _AppRootHomeState extends State<_AppRootHome> {
  bool _firebaseReady = false;
  bool _appInitDone = false;
  Object? _firebaseError;

  final AppLifecycleBackupService _lifecycleBackupService =
      AppLifecycleBackupService();

  @override
  void initState() {
    super.initState();
    StartupTracker.instance.markOnce('app_root_home_init');
    // Read any cold-start widget launch now (during the splash, while the
    // isolate is idle awaiting Firebase) so the action is known before auth
    // resolves — that's what lets the shell skip the dashboard build.
    HomeWidgetService.instance.captureInitialLaunch();
    _boot();
  }

  @override
  void dispose() {
    _lifecycleBackupService.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    // 1. Await Firebase (running in background since kickoff()).
    try {
      await StartupOrchestrator.instance.firebaseReady;
      if (!mounted) return;
      // Firebase is up — start the single auth source of truth listening.
      context.read<AuthController>().init();
      setState(() => _firebaseReady = true);
      StartupTracker.instance.markOnce('firebase_ready_in_ui');
    } catch (e) {
      AppLogger.error('AppRoot: Firebase failed', e);
      if (!mounted) return;
      setState(() => _firebaseError = e);
      return;
    }

    // 2. Run app-level init (settings, debug logs, migrations, backup, reminders).
    await _runAppInit();
    if (!mounted) return;
    setState(() => _appInitDone = true);
    StartupTracker.instance.markOnce('app_init_done');
  }

  Future<void> _runAppInit() async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();

    await SettingsService.loadSettings(settingsState, settingsRepository);
    StartupTracker.instance.mark('settings_loaded');

    // Fire-and-forget: non-blocking tasks.
    _initDebugLogsAsync(settingsState);
    _runImageCompressionMigrationAsync();

    await _initAutoBackup(settingsState, settingsRepository);
    StartupTracker.instance.mark('auto_backup_scheduled');
    await _initPendingOrdersReminder(settingsState);
    StartupTracker.instance.mark('reminders_scheduled');

    // Fire-and-forget: audio backup cleanup.
    Future.microtask(() => AudioBackupCleanupService.runCleanup());
  }

  void _initDebugLogsAsync(SettingsState settingsState) {
    if (!settingsState.debugLogsEnabled) return;
    _enableDebugLogs();
  }

  Future<void> _enableDebugLogs() async {
    try {
      await AppLogger.enableFileLogging().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.warning('Debug logs initialization timed out');
        },
      );
    } catch (e) {
      AppLogger.warning('Failed to initialize debug logs: $e');
    }
  }

  void _runImageCompressionMigrationAsync() {
    ImageCompressionMigration.run().then((_) {}, onError: (Object e) {
      AppLogger.warning('Image compression migration failed: $e');
    });
  }

  Future<void> _initAutoBackup(
    SettingsState settingsState,
    SettingsRepository settingsRepository,
  ) async {
    if (settingsState.autoBackupEnabled) {
      await AutoBackupService.scheduleAutoBackup(settingsState.autoBackupTime);
    }

    _lifecycleBackupService.initialize(
      settingsRepository: settingsRepository,
      onBackupComplete: () {
        SettingsService.loadSettings(settingsState, settingsRepository);
      },
    );

    // Fire-and-forget: startup backup check happens after MainShellScreen mounts.
    // We schedule it here so it runs once init is done but doesn't block UI.
    Future.microtask(() => _lifecycleBackupService.checkOnStartup());
  }

  Future<void> _initPendingOrdersReminder(
      SettingsState settingsState) async {
    if (settingsState.pendingOrdersReminderEnabled) {
      await PendingOrdersReminderService.scheduleReminder(
        settingsState.pendingOrdersReminderTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firebaseError != null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Failed to connect. Please check your internet connection and restart the app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Show splash until Firebase is ready.
    if (!_firebaseReady || !_appInitDone) {
      return const Scaffold(
        body: Center(child: AppLogo(size: 120)),
      );
    }

    StartupTracker.instance.markOnce('auth_gate_rendered');
    return const _AuthGate();
  }
}

/// Auth-gating widget — mirrors old AuthGate but lives inside the single
/// MaterialApp, so it inherits theme/nav correctly.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  int _refreshKey = 0;
  bool _widgetDispatchScheduled = false;

  void _onBackupChoiceCompleted() {
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    // Single source of truth. Tri-state means we NEVER mistake "auth not
    // resolved yet" (unknown) for "signed out" — that transient-null confusion
    // is what flashed LoginScreen for signed-in users (and lost data once).
    final auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.unknown:
        StartupTracker.instance.markOnce('auth_gate_waiting_for_stream');
        return const Scaffold(body: Center(child: AppLogo(size: 120)));

      case AuthStatus.unauthenticated:
        StartupTracker.instance.markOnce('auth_gate_to_login');
        // Don't dispatch widget deep links into a login screen; re-arm on
        // next sign-in.
        _widgetDispatchScheduled = false;
        HomeWidgetService.instance.markShellGone();
        return const LoginScreen();

      case AuthStatus.authenticated:
        final user = auth.user!;
        // Fire-and-forget: silent sign-in keeps the Drive token fresh.
        AuthService.silentSignIn().catchError((e) {
          AppLogger.warning('Silent sign-in failed: $e');
        });

        return FutureBuilder<bool>(
          key: ValueKey(_refreshKey),
          future: OnboardingService.hasCompletedBackupChoice(user.uid),
          builder: (context, choiceSnapshot) {
            if (choiceSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final hasCompleted = choiceSnapshot.data ?? false;

            if (!hasCompleted) {
              StartupTracker.instance
                  .markOnce('auth_gate_backup_restore_check');
              return BackupRestoreCheckScreen(
                onComplete: () async {
                  await OnboardingService.setBackupChoiceCompleted(user.uid);
                  _onBackupChoiceCompleted();
                },
              );
            }

            StartupTracker.instance.markOnce('auth_gate_to_main_shell');
            // Mark the shell ready the instant we're authenticated. If a
            // widget launch is pending (captured during the splash), this
            // covers the shell *before* HomeShellHost's first build, so the
            // dashboard is skipped entirely until the user returns from the
            // launched destination.
            if (!_widgetDispatchScheduled) {
              _widgetDispatchScheduled = true;
              HomeWidgetService.instance.markShellReady();
            }
            return const HomeShellHost();
          },
        );
    }
  }
}
