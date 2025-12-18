import 'dart:convert';
import 'package:hive/hive.dart';
import '../../backend/backend.dart';
import '../../constants/app_constants.dart';

class BackupService {
  static const String _backupVersion = '1.0.0';
  static const String _appVersion = '1.0.0';

  static const String _versionKey = 'version';
  static const String _timestampKey = 'timestamp';
  static const String _appVersionKey = 'appVersion';
  static const String _boxesKey = 'boxes';
  static const String _metadataKey = 'metadata';
  static const String _customersKey = 'customers';
  static const String _ordersKey = 'orders';
  static const String _settingsKey = 'settings';
  static const String _customerCountKey = 'customerCount';
  static const String _orderCountKey = 'orderCount';

  static Future<String> createBackup() async {
    final customersBox = DatabaseService.getCustomersBox();
    final ordersBox = DatabaseService.getOrdersBox();
    final settingsBox = DatabaseService.getSettingsBox();

    final settings = settingsBox.get(AppConstants.settingsKey);

    final backup = {
      _versionKey: _backupVersion,
      _timestampKey: DateTime.now().toIso8601String(),
      _appVersionKey: _appVersion,
      _boxesKey: {
        _customersKey: customersBox.values.map((c) => c.toJson()).toList(),
        _ordersKey: ordersBox.values.map((o) => o.toJson()).toList(),
        _settingsKey: settings?.toJson(),
      },
      _metadataKey: {
        _customerCountKey: customersBox.length,
        _orderCountKey: ordersBox.length,
      },
    };

    return jsonEncode(backup);
  }

  static Future<void> restoreBackup(String backupJson) async {
    final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
    _validateBackup(backupData);

    final customersBox = DatabaseService.getCustomersBox();
    final ordersBox = DatabaseService.getOrdersBox();
    final settingsBox = DatabaseService.getSettingsBox();

    await Future.wait([
      customersBox.clear(),
      ordersBox.clear(),
    ]);

    final boxes = backupData[_boxesKey] as Map<String, dynamic>;

    await _restoreCustomers(boxes, customersBox);
    await _restoreOrders(boxes, ordersBox);
    await _restoreSettings(boxes, settingsBox);
  }

  static Future<void> _restoreCustomers(
    Map<String, dynamic> boxes,
    Box<Customer> customersBox,
  ) async {
    final customersList = boxes[_customersKey] as List?;
    if (customersList == null) return;

    for (var json in customersList) {
      final customer = Customer.fromJson(json as Map<String, dynamic>);
      await customersBox.put(customer.id, customer);
    }
  }

  static Future<void> _restoreOrders(
    Map<String, dynamic> boxes,
    Box<Order> ordersBox,
  ) async {
    final ordersList = boxes[_ordersKey] as List?;
    if (ordersList == null) return;

    for (var json in ordersList) {
      final order = Order.fromJson(json as Map<String, dynamic>);
      await ordersBox.put(order.id, order);
    }
  }

  static Future<void> _restoreSettings(
    Map<String, dynamic> boxes,
    Box<AppSettings> settingsBox,
  ) async {
    final settingsJson = boxes[_settingsKey] as Map<String, dynamic>?;
    if (settingsJson == null) return;

    final settings = AppSettings.fromJson(settingsJson);
    await settingsBox.put(AppConstants.settingsKey, settings);
  }

  static void _validateBackup(Map<String, dynamic> backupData) {
    if (!backupData.containsKey(_versionKey)) {
      throw Exception('Invalid backup: missing version');
    }

    if (!backupData.containsKey(_boxesKey)) {
      throw Exception('Invalid backup: missing boxes');
    }

    final version = backupData[_versionKey] as String;
    if (version != _backupVersion) {
      throw Exception('Incompatible backup version: $version (expected $_backupVersion)');
    }
  }

  static Map<String, dynamic> getBackupMetadata(String backupJson) {
    final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
    final metadata = backupData[_metadataKey] as Map<String, dynamic>?;

    return {
      _versionKey: backupData[_versionKey],
      _timestampKey: backupData[_timestampKey],
      _appVersionKey: backupData[_appVersionKey],
      _customerCountKey: metadata?[_customerCountKey] ?? 0,
      _orderCountKey: metadata?[_orderCountKey] ?? 0,
    };
  }
}

