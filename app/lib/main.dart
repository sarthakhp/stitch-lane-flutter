import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'backend/backend.dart';
import 'domain/domain.dart';
import 'config/routes.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell_screen.dart';
import 'screens/backup_restore_check_screen.dart';
import 'utils/app_logger.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      AppLogger.info('[Workmanager] Task triggered: $task');

      if (task == autoBackupTaskName) {
        await AutoBackupService.performBackup();
      } else if (task == pendingOrdersReminderTaskName) {
        await PendingOrdersReminderService.performReminder();
      } else {
        AppLogger.warning('[Workmanager] Unknown task: $task');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('[Workmanager] Task failed: $task', e);
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.initializeAuthPersistence();
  await DatabaseService.initialize();
  await NotificationService.initialize();
  await BackgroundTaskDispatcher.initialize(callbackDispatcher);
  runApp(const StitchLaneApp());
}

class StitchLaneApp extends StatelessWidget {
  const StitchLaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => BackupState()),
        ChangeNotifierProvider(create: (_) => CustomerState()),
        Provider<CustomerRepository>(
          create: (_) => HiveCustomerRepository(),
        ),
        ChangeNotifierProvider(create: (_) => OrderState()),
        Provider<OrderRepository>(
          create: (_) => HiveOrderRepository(),
        ),
        ChangeNotifierProvider(create: (_) => MeasurementState()),
        Provider<MeasurementRepository>(
          create: (_) => HiveMeasurementRepository(),
        ),
        ChangeNotifierProvider(create: (_) => SettingsState()),
        Provider<SettingsRepository>(
          create: (_) => HiveSettingsRepository(),
        ),
        ChangeNotifierProvider(create: (_) => MainShellState()),
      ],
      child: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitializing = true;
  final AppLifecycleBackupService _lifecycleBackupService = AppLifecycleBackupService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _lifecycleBackupService.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();

    await Future.delayed(const Duration(milliseconds: 100));

    final currentUser = AuthService.getCurrentUser();

    if (currentUser != null) {
      await AuthService.silentSignIn();
    }

    await SettingsService.loadSettings(settingsState, settingsRepository);

    await _initializeAutoBackup(settingsState, settingsRepository);
    await _initializePendingOrdersReminder(settingsState);

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _initializeAutoBackup(
    SettingsState settingsState,
    SettingsRepository settingsRepository,
  ) async {
    if (settingsState.autoBackupEnabled) {
      await AutoBackupService.scheduleAutoBackup(settingsState.autoBackupTime);
    }

    _lifecycleBackupService.initialize(
      onBackupComplete: () {
        SettingsService.loadSettings(settingsState, settingsRepository);
      },
    );

    Future.microtask(() => _lifecycleBackupService.checkOnStartup());
  }

  Future<void> _initializePendingOrdersReminder(SettingsState settingsState) async {
    if (settingsState.pendingOrdersReminderEnabled) {
      await PendingOrdersReminderService.scheduleReminder(
        settingsState.pendingOrdersReminderTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Stitch Lane',
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
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _refreshKey = 0;

  void _onBackupChoiceCompleted() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        if (user != null) {
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
                return BackupRestoreCheckScreen(
                  onComplete: () async {
                    await OnboardingService.setBackupChoiceCompleted(user.uid);
                    _onBackupChoiceCompleted();
                  },
                );
              }

              return const MainShellScreen();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}



