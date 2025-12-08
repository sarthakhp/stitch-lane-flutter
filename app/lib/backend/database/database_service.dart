import 'package:hive_flutter/hive_flutter.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/app_settings.dart';
import '../../constants/app_constants.dart';

class DatabaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      Hive.registerAdapter(CustomerAdapter());
      Hive.registerAdapter(OrderAdapter());
      Hive.registerAdapter(OrderStatusAdapter());
      Hive.registerAdapter(AppSettingsAdapter());
      await Hive.openBox<Customer>(AppConstants.customersBoxName);
      await Hive.openBox<Order>(AppConstants.ordersBoxName);
      await Hive.openBox<AppSettings>(AppConstants.settingsBoxName);
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  static Box<Customer> getCustomersBox() {
    if (!_initialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return Hive.box<Customer>(AppConstants.customersBoxName);
  }

  static Box<Order> getOrdersBox() {
    if (!_initialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return Hive.box<Order>(AppConstants.ordersBoxName);
  }

  static Box<AppSettings> getSettingsBox() {
    if (!_initialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return Hive.box<AppSettings>(AppConstants.settingsBoxName);
  }

  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }
}

