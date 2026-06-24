import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';
import 'backend/backend.dart';
import 'domain/domain.dart';
import 'domain/services/home_widget/home_widget_service.dart';
import 'screens/app_root.dart';
import 'utils/app_logger.dart';
import 'utils/startup_tracker.dart';
import 'utils/startup_orchestrator.dart';

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
  StartupTracker.instance.start();
  WidgetsFlutterBinding.ensureInitialized();
  StartupTracker.instance.mark('binding_ready');

  await dotenv.load(fileName: '.env');
  StartupTracker.instance.mark('dotenv_loaded');

  // Snapshot the live DB BEFORE any open/migration. If a migration corrupts
  // the file, or some other code path wipes it, the pre-launch snapshot at
  // <databases>/snapshots/<ts>/ is the rollback. Safe to fail — never blocks
  // boot. Throttled to one snapshot per 30 minutes regardless of restarts.
  await DbSnapshotService.snapshotBeforeOpen();
  StartupTracker.instance.mark('db_snapshot_done');

  // Database must be ready before the first widget tree builds.
  await DatabaseService.initialize();
  StartupTracker.instance.mark('database_initialized');

  // Wire the AI gateway's usage recorder to SQLite. Must happen after the DB
  // is up and before any service that emits LLM calls is constructed.
  AiGateway.instance.init();
  StartupTracker.instance.mark('ai_gateway_initialized');

  // WorkManager handler must be registered before runApp so the background
  // isolate can route tasks correctly. This takes ~16ms and is required.
  await BackgroundTaskDispatcher.initialize(callbackDispatcher);
  StartupTracker.instance.mark('workmanager_initialized');

  // Subscribe to live home-screen widget taps. The cold-start launch action is
  // read later (HomeWidgetService.captureInitialLaunch) once the plugin is up.
  HomeWidgetService.instance.init();
  StartupTracker.instance.mark('home_widget_initialized');

  runApp(const StitchGenieApp());
  StartupTracker.instance.mark('runapp_returned');

  // Kick off Firebase + auth + notifications in the background — the UI will
  // show a splash until firebaseReady completes (usually < 1s on warm network).
  StartupOrchestrator.instance.kickoff();
}

class StitchGenieApp extends StatelessWidget {
  const StitchGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Single source of truth for auth (lazy: first read by the gate, which
        // runs after Firebase is initialized).
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => BackupState()),
        ChangeNotifierProvider(create: (_) => CustomerState()),
        Provider<CustomerRepository>(
          create: (_) => RepositoryFactory.createCustomerRepository(),
        ),
        ChangeNotifierProvider(create: (_) => OrderState()),
        Provider<OrderRepository>(
          create: (_) => RepositoryFactory.createOrderRepository(),
        ),
        ChangeNotifierProvider(create: (_) => MeasurementState()),
        Provider<MeasurementRepository>(
          create: (_) => RepositoryFactory.createMeasurementRepository(),
        ),
        ChangeNotifierProvider(create: (_) => SettingsState()),
        Provider<SettingsRepository>(
          create: (_) => RepositoryFactory.createSettingsRepository(),
        ),
        ChangeNotifierProvider(create: (_) => MeasurementFieldsState()),
        Provider<MeasurementFieldRepository>(
          create: (_) => RepositoryFactory.createMeasurementFieldRepository(),
        ),
        ChangeNotifierProvider(create: (_) => MainShellState()),
        // Permission state is read by the home banner and main-shell init.
        // init() is called once from MainShellScreen (post-Firebase, post-auth).
        ChangeNotifierProvider(create: (_) => PermissionController()),
      ],
      child: const AppRoot(),
    );
  }
}
