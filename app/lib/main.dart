import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'backend/backend.dart';
import 'domain/domain.dart';
import 'config/routes.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthService.initializeAuthPersistence();
  await DatabaseService.initialize();
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
        ChangeNotifierProvider(create: (_) => SettingsState()),
        Provider<SettingsRepository>(
          create: (_) => HiveSettingsRepository(),
        ),
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

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    AuthService.authStateChanges().listen((user) {
      if (mounted) {
        final authState = context.read<AuthState>();
        if (user != null) {
          authState.setUser(user);
        } else {
          authState.signOut();
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    final authState = context.read<AuthState>();
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();

    await Future.delayed(const Duration(milliseconds: 100));

    final currentUser = AuthService.getCurrentUser();

    if (currentUser != null) {
      authState.setUser(currentUser);
      await AuthService.silentSignIn();
    }

    await SettingsService.loadSettings(settingsState, settingsRepository);

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    if (authState.isAuthenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}

