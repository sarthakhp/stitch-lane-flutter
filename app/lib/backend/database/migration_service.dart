import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../utils/app_logger.dart';
import '../repositories/hive_customer_repository.dart';
import '../repositories/hive_order_repository.dart';
import '../repositories/hive_measurement_repository.dart';
import '../repositories/hive_settings_repository.dart';
import '../repositories/sqlite_customer_repository.dart';
import '../repositories/sqlite_order_repository.dart';
import '../repositories/sqlite_measurement_repository.dart';
import '../repositories/sqlite_settings_repository.dart';
import 'sqlite_database.dart';

enum MigrationResult { success, verificationFailed, failed, noDataToMigrate }

class MigrationService {
  static const String _migrationStatusKey = 'db_migration_status';
  static const String _statusCompleted = 'completed';

  static Future<bool> isMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_migrationStatusKey) == _statusCompleted;
  }

  static Future<bool> needsMigration() async {
    if (await isMigrationCompleted()) return false;
    return _hiveHasData();
  }

  static Future<bool> _hiveHasData() async {
    try {
      final hiveCustomers = HiveCustomerRepository();
      final hiveOrders = HiveOrderRepository();
      final hiveMeasurements = HiveMeasurementRepository();

      final customers = await hiveCustomers.getAllCustomers();
      final orders = await hiveOrders.getAllOrders();
      final measurements = await hiveMeasurements.getAllMeasurements();

      return customers.isNotEmpty || orders.isNotEmpty || measurements.isNotEmpty;
    } catch (e) {
      AppLogger.error('Failed to check Hive data', e);
      return false;
    }
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_migrationStatusKey, _statusCompleted);
  }

  static Future<MigrationResult> migrateHiveToSqlite() async {
    try {
      AppLogger.info('Starting Hive to SQLite migration...');

      // 1. Read all data from Hive
      final hiveCustomers = HiveCustomerRepository();
      final hiveOrders = HiveOrderRepository();
      final hiveMeasurements = HiveMeasurementRepository();
      final hiveSettings = HiveSettingsRepository();

      final customers = await hiveCustomers.getAllCustomers();
      final orders = await hiveOrders.getAllOrders();
      final measurements = await hiveMeasurements.getAllMeasurements();
      final settings = await hiveSettings.getSettings();

      AppLogger.info(
        'Hive data read: ${customers.length} customers, '
        '${orders.length} orders, ${measurements.length} measurements',
      );

      if (customers.isEmpty && orders.isEmpty && measurements.isEmpty) {
        AppLogger.info('No Hive data to migrate');
        await markCompleted();
        return MigrationResult.noDataToMigrate;
      }

      // 2. Initialize SQLite and write all data in a single transaction
      await SqliteDatabase.withForeignKeysDisabled(() async {
        final db = await SqliteDatabase.database;
        await db.transaction((txn) async {
          for (final customer in customers) {
            await txn.insert('customers', SqliteCustomerRepository.toMap(customer));
          }
          for (final order in orders) {
            await txn.insert('orders', SqliteOrderRepository.toMap(order));
          }
          for (final measurement in measurements) {
            await txn.insert('measurements', SqliteMeasurementRepository.toMap(measurement));
          }
          await txn.insert('settings', SqliteSettingsRepository.toMap(settings),
              conflictAlgorithm: ConflictAlgorithm.replace);
        });
      });

      // 3. Verify counts match
      final verifyDb = await SqliteDatabase.database;
      final sqliteCustomerCount =
          Sqflite.firstIntValue(await verifyDb.rawQuery('SELECT COUNT(*) FROM customers')) ?? 0;
      final sqliteOrderCount =
          Sqflite.firstIntValue(await verifyDb.rawQuery('SELECT COUNT(*) FROM orders')) ?? 0;
      final sqliteMeasurementCount =
          Sqflite.firstIntValue(await verifyDb.rawQuery('SELECT COUNT(*) FROM measurements')) ?? 0;

      if (sqliteCustomerCount != customers.length ||
          sqliteOrderCount != orders.length ||
          sqliteMeasurementCount != measurements.length) {
        AppLogger.error(
          'Migration verification failed! '
          'Hive: ${customers.length}/${orders.length}/${measurements.length}, '
          'SQLite: $sqliteCustomerCount/$sqliteOrderCount/$sqliteMeasurementCount',
        );
        await SqliteDatabase.deleteDb();
        return MigrationResult.verificationFailed;
      }

      // 4. Mark migration as complete
      await markCompleted();

      AppLogger.info(
        'Migration completed successfully: '
        '$sqliteCustomerCount customers, $sqliteOrderCount orders, '
        '$sqliteMeasurementCount measurements',
      );

      return MigrationResult.success;
    } catch (e) {
      AppLogger.error('Migration failed', e);
      try {
        await SqliteDatabase.deleteDb();
      } catch (deleteError) {
        AppLogger.error('Failed to clean up SQLite after migration failure', deleteError);
      }
      return MigrationResult.failed;
    }
  }

}
