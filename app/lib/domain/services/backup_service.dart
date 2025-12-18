import 'dart:convert';
import 'package:hive/hive.dart';
import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import 'image_sync_service.dart';
import '../../utils/app_logger.dart';

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
  static const String _measurementsKey = 'measurements';
  static const String _settingsKey = 'settings';
  static const String _customerCountKey = 'customerCount';
  static const String _orderCountKey = 'orderCount';
  static const String _measurementCountKey = 'measurementCount';

  static Future<String> createBackup() async {
    final customersBox = DatabaseService.getCustomersBox();
    final ordersBox = DatabaseService.getOrdersBox();
    final measurementsBox = DatabaseService.getMeasurementsBox();
    final settingsBox = DatabaseService.getSettingsBox();

    final settings = settingsBox.get(AppConstants.settingsKey);

    final backup = {
      _versionKey: _backupVersion,
      _timestampKey: DateTime.now().toIso8601String(),
      _appVersionKey: _appVersion,
      _boxesKey: {
        _customersKey: customersBox.values.map((c) => c.toJson()).toList(),
        _ordersKey: ordersBox.values.map((o) => o.toJson()).toList(),
        _measurementsKey: measurementsBox.values.map((m) => m.toJson()).toList(),
        _settingsKey: settings?.toJson(),
      },
      _metadataKey: {
        _customerCountKey: customersBox.length,
        _orderCountKey: ordersBox.length,
        _measurementCountKey: measurementsBox.length,
      },
    };

    return jsonEncode(backup);
  }

  static Future<void> restoreBackup(String backupJson) async {
    final backupData = jsonDecode(backupJson) as Map<String, dynamic>;
    _validateBackup(backupData);

    final customersBox = DatabaseService.getCustomersBox();
    final ordersBox = DatabaseService.getOrdersBox();
    final measurementsBox = DatabaseService.getMeasurementsBox();
    final settingsBox = DatabaseService.getSettingsBox();

    await Future.wait([
      customersBox.clear(),
      ordersBox.clear(),
      measurementsBox.clear(),
    ]);

    final boxes = backupData[_boxesKey] as Map<String, dynamic>;

    await _restoreCustomers(boxes, customersBox);
    await _restoreOrders(boxes, ordersBox);
    await _restoreMeasurements(boxes, measurementsBox);
    await _restoreSettings(boxes, settingsBox);

    try {
      AppLogger.info('Starting image download from Drive after restore');
      await ImageSyncService.downloadImagesFromDrive();
      AppLogger.info('Images restored successfully');
    } catch (e) {
      AppLogger.error('Failed to restore images from Drive', e);
    }
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

  static Future<void> _restoreMeasurements(
    Map<String, dynamic> boxes,
    Box<Measurement> measurementsBox,
  ) async {
    final measurementsList = boxes[_measurementsKey] as List?;
    if (measurementsList == null) return;

    for (var json in measurementsList) {
      final measurement = Measurement.fromJson(json as Map<String, dynamic>);
      await measurementsBox.put(measurement.id, measurement);
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
      _measurementCountKey: metadata?[_measurementCountKey] ?? 0,
    };
  }
}

