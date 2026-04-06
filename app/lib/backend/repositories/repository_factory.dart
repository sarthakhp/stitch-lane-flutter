import '../database/database_service.dart';
import 'customer_repository.dart';
import 'hive_customer_repository.dart';
import 'sqlite_customer_repository.dart';
import 'order_repository.dart';
import 'hive_order_repository.dart';
import 'sqlite_order_repository.dart';
import 'measurement_repository.dart';
import 'hive_measurement_repository.dart';
import 'sqlite_measurement_repository.dart';
import 'settings_repository.dart';
import 'hive_settings_repository.dart';
import 'sqlite_settings_repository.dart';

class RepositoryFactory {
  static CustomerRepository createCustomerRepository() {
    if (DatabaseService.isUsingSqlite) {
      return SqliteCustomerRepository();
    }
    return HiveCustomerRepository();
  }

  static OrderRepository createOrderRepository() {
    if (DatabaseService.isUsingSqlite) {
      return SqliteOrderRepository();
    }
    return HiveOrderRepository();
  }

  static MeasurementRepository createMeasurementRepository() {
    if (DatabaseService.isUsingSqlite) {
      return SqliteMeasurementRepository();
    }
    return HiveMeasurementRepository();
  }

  static SettingsRepository createSettingsRepository() {
    if (DatabaseService.isUsingSqlite) {
      return SqliteSettingsRepository();
    }
    return HiveSettingsRepository();
  }
}
