import 'customer_repository.dart';
import 'sqlite_customer_repository.dart';
import 'order_repository.dart';
import 'sqlite_order_repository.dart';
import 'measurement_repository.dart';
import 'sqlite_measurement_repository.dart';
import 'settings_repository.dart';
import 'sqlite_settings_repository.dart';
import 'measurement_field_repository.dart';
import 'sqlite_measurement_field_repository.dart';

class RepositoryFactory {
  static CustomerRepository createCustomerRepository() {
    return SqliteCustomerRepository();
  }

  static OrderRepository createOrderRepository() {
    return SqliteOrderRepository();
  }

  static MeasurementRepository createMeasurementRepository() {
    return SqliteMeasurementRepository();
  }

  static SettingsRepository createSettingsRepository() {
    return SqliteSettingsRepository();
  }

  static MeasurementFieldRepository createMeasurementFieldRepository() {
    return SqliteMeasurementFieldRepository();
  }
}
