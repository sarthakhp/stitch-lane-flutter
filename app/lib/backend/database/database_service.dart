import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/app_settings.dart';
import '../models/measurement.dart';
import '../models/payment_entry.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import 'sqlite_database.dart';
import 'migration_service.dart';

class DatabaseService {
  static bool _initialized = false;
  static bool _usingSqlite = false;
  static bool _hiveBoxesOpened = false;

  static bool get isUsingSqlite => _usingSqlite;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Always init Hive framework (needed for adapter registration during transition)
      await _initHiveFramework();

      // Check migration status
      final migrationCompleted = await MigrationService.isMigrationCompleted();

      if (migrationCompleted) {
        // SQLite is the active database
        await SqliteDatabase.database;
        _usingSqlite = true;
        AppLogger.info('DatabaseService: Using SQLite (migration previously completed)');
      } else {
        // Open Hive boxes (needed for migration or running on Hive)
        await _openHiveBoxes();

        if (await MigrationService.needsMigration()) {
          // Existing Hive data — migrate it
          AppLogger.info('DatabaseService: Hive data found, starting migration...');
          final result = await MigrationService.migrateHiveToSqlite();

          if (result == MigrationResult.success ||
              result == MigrationResult.noDataToMigrate) {
            _usingSqlite = true;
            AppLogger.info('DatabaseService: Migration successful, using SQLite');
          } else {
            _usingSqlite = false;
            AppLogger.error('DatabaseService: Migration failed, falling back to Hive');
          }
        } else {
          // Fresh install — go straight to SQLite
          await SqliteDatabase.database;
          await MigrationService.markCompleted();
          _usingSqlite = true;
          AppLogger.info('DatabaseService: Fresh install, using SQLite');
        }
      }

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  static Future<void> _initHiveFramework() async {
    await Hive.initFlutter();
    _registerHiveAdapters();
  }

  static void _registerHiveAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CustomerAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(OrderAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(OrderStatusAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(AppSettingsAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(MeasurementAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(PaymentEntryAdapter());
  }

  static Future<void> _openHiveBoxes() async {
    if (_hiveBoxesOpened) return;
    await Hive.openBox<Customer>(AppConstants.customersBoxName);
    await Hive.openBox<Order>(AppConstants.ordersBoxName);
    await Hive.openBox<AppSettings>(AppConstants.settingsBoxName);
    await Hive.openBox<Measurement>(AppConstants.measurementsBoxName);
    _hiveBoxesOpened = true;
  }

  // Hive box getters — kept for fallback and migration reads
  static Box<Customer> getCustomersBox() {
    if (!_hiveBoxesOpened) {
      throw Exception('Hive boxes not opened. Call initialize() first.');
    }
    return Hive.box<Customer>(AppConstants.customersBoxName);
  }

  static Box<Order> getOrdersBox() {
    if (!_hiveBoxesOpened) {
      throw Exception('Hive boxes not opened. Call initialize() first.');
    }
    return Hive.box<Order>(AppConstants.ordersBoxName);
  }

  static Box<AppSettings> getSettingsBox() {
    if (!_hiveBoxesOpened) {
      throw Exception('Hive boxes not opened. Call initialize() first.');
    }
    return Hive.box<AppSettings>(AppConstants.settingsBoxName);
  }

  static Box<Measurement> getMeasurementsBox() {
    if (!_hiveBoxesOpened) {
      throw Exception('Hive boxes not opened. Call initialize() first.');
    }
    return Hive.box<Measurement>(AppConstants.measurementsBoxName);
  }

  static Future<void> close() async {
    if (_usingSqlite) {
      await SqliteDatabase.close();
    }
    if (_hiveBoxesOpened) {
      await Hive.close();
      _hiveBoxesOpened = false;
    }
    _initialized = false;
  }
}
