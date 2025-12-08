import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'backend/backend.dart';
import 'domain/domain.dart';
import 'config/routes.dart';
import 'constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.initialize();
  runApp(const StitchLaneApp());
}

class StitchLaneApp extends StatelessWidget {
  const StitchLaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialSettings();
    });
  }

  Future<void> _loadInitialSettings() async {
    final settingsState = context.read<SettingsState>();
    final settingsRepository = context.read<SettingsRepository>();
    await SettingsService.loadSettings(settingsState, settingsRepository);
  }

  @override
  Widget build(BuildContext context) {
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
      initialRoute: AppConstants.homeRoute,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}

