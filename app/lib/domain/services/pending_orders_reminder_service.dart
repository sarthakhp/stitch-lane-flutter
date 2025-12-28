import 'package:hive_flutter/hive_flutter.dart';
import '../../backend/backend.dart';
import '../../constants/app_constants.dart';
import '../../utils/app_logger.dart';
import '../models/pending_orders_data.dart';
import 'daily_task_scheduler.dart';
import 'notification_service.dart';

const String pendingOrdersReminderTaskName = 'com.stitchlane.pendingordersreminder';
const String pendingOrdersReminderTaskTag = 'pending_orders_reminder';

class PendingOrdersReminderService {
  static const _scheduler = DailyTaskScheduler(
    taskName: pendingOrdersReminderTaskName,
    taskTag: pendingOrdersReminderTaskTag,
  );

  static Future<void> scheduleReminder(String timeString) async {
    await _scheduler.schedule(timeString);
  }

  static Future<void> cancelReminder() async {
    await _scheduler.cancel();
  }

  static Future<void> scheduleTest({int delaySeconds = 15}) async {
    await _scheduler.scheduleTest(delaySeconds: delaySeconds);
  }

  static Future<void> performReminder() async {
    try {
      AppLogger.info('Starting pending orders reminder...');

      await _initializeForBackground();

      final data = await _aggregatePendingOrdersData();

      if (data.hasOrders) {
        await NotificationService.showPendingOrdersReminderNotification(data);
        AppLogger.info('Pending orders notification shown: ${data.totalPendingOrders} orders from ${data.customers.length} customers');
      } else {
        await NotificationService.showNoPendingOrdersNotification();
        AppLogger.info('No pending orders notification shown');
      }

      await _scheduleNextIfEnabled();

      AppLogger.info('Pending orders reminder completed');
    } catch (e) {
      AppLogger.error('Pending orders reminder failed', e);
      await _scheduleNextIfEnabled();
      rethrow;
    }
  }

  static Future<void> _scheduleNextIfEnabled() async {
    try {
      final settings = await _getSettings();
      if (settings.pendingOrdersReminderEnabled) {
        await _scheduler.scheduleNextDay(settings.pendingOrdersReminderTime);
        AppLogger.info('Next pending orders reminder scheduled for tomorrow');
      }
    } catch (e) {
      AppLogger.error('Failed to schedule next reminder', e);
    }
  }

  static Future<AppSettings> _getSettings() async {
    final settingsBox = Hive.box<AppSettings>(AppConstants.settingsBoxName);
    return settingsBox.get(AppConstants.settingsKey) ?? AppSettings();
  }

  static Future<PendingOrdersData> _aggregatePendingOrdersData() async {
    final ordersBox = Hive.box<Order>(AppConstants.ordersBoxName);
    final customersBox = Hive.box<Customer>(AppConstants.customersBoxName);
    final settingsBox = Hive.box<AppSettings>(AppConstants.settingsBoxName);

    final settings = settingsBox.get(AppConstants.settingsKey) ?? AppSettings();
    final thresholdDays = settings.dueDateWarningThreshold;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thresholdDate = today.add(Duration(days: thresholdDays));

    final allOrders = ordersBox.values.toList();
    final allCustomers = customersBox.values.toList();

    final customerMap = {for (var c in allCustomers) c.id: c};

    final pendingOrdersWithinThreshold = allOrders.where((order) {
      if (order.status != OrderStatus.pending) return false;
      final orderDueDate = DateTime(
        order.dueDate.year,
        order.dueDate.month,
        order.dueDate.day,
      );
      return !orderDueDate.isAfter(thresholdDate);
    }).toList();

    final Map<String, List<Order>> ordersByCustomer = {};
    for (final order in pendingOrdersWithinThreshold) {
      ordersByCustomer.putIfAbsent(order.customerId, () => []).add(order);
    }

    final List<CustomerPendingInfo> customerInfoList = [];
    int totalPendingOrders = 0;

    for (final entry in ordersByCustomer.entries) {
      final customer = customerMap[entry.key];
      if (customer == null) continue;

      final pendingOrders = entry.value;
      final pendingCount = pendingOrders.length;
      totalPendingOrders += pendingCount;

      final readyCount = allOrders
          .where((o) => o.customerId == entry.key && o.status == OrderStatus.ready)
          .length;

      final nearestDueDate = pendingOrders
          .map((o) => o.dueDate)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      customerInfoList.add(CustomerPendingInfo(
        customerId: customer.id,
        customerName: customer.name,
        pendingOrderCount: pendingCount,
        readyOrderCount: readyCount,
        nearestDueDate: nearestDueDate,
      ));
    }

    customerInfoList.sort((a, b) => a.nearestDueDate.compareTo(b.nearestDueDate));

    return PendingOrdersData(
      customers: customerInfoList,
      totalPendingOrders: totalPendingOrders,
    );
  }

  static Future<void> _initializeForBackground() async {
    if (!Hive.isBoxOpen(AppConstants.customersBoxName)) {
      await Hive.initFlutter();
      _registerAdaptersIfNeeded();
      await Hive.openBox<Customer>(AppConstants.customersBoxName);
      await Hive.openBox<Order>(AppConstants.ordersBoxName);
      await Hive.openBox<AppSettings>(AppConstants.settingsBoxName);
      await Hive.openBox<Measurement>(AppConstants.measurementsBoxName);
    }
    await NotificationService.initialize();
  }

  static void _registerAdaptersIfNeeded() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CustomerAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(OrderAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(OrderStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(MeasurementAdapter());
    }
  }
}

