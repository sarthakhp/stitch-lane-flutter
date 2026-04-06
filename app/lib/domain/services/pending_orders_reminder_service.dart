import '../../backend/backend.dart';
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

      final orderRepository = RepositoryFactory.createOrderRepository();
      final customerRepository = RepositoryFactory.createCustomerRepository();
      final settingsRepository = RepositoryFactory.createSettingsRepository();

      final data = await _aggregatePendingOrdersData(
        orderRepository: orderRepository,
        customerRepository: customerRepository,
        settingsRepository: settingsRepository,
      );

      if (data.hasOrders) {
        await NotificationService.showPendingOrdersReminderNotification(data);
        AppLogger.info('Pending orders notification shown: ${data.totalPendingOrders} orders from ${data.customers.length} customers');
      } else {
        await NotificationService.showNoPendingOrdersNotification();
        AppLogger.info('No pending orders notification shown');
      }

      await _scheduleNextIfEnabled(settingsRepository);

      AppLogger.info('Pending orders reminder completed');
    } catch (e) {
      AppLogger.error('Pending orders reminder failed', e);
      try {
        final settingsRepository = RepositoryFactory.createSettingsRepository();
        await _scheduleNextIfEnabled(settingsRepository);
      } catch (scheduleError) {
        AppLogger.error('Failed to schedule next reminder after failure', scheduleError);
      }
      rethrow;
    }
  }

  static Future<void> _scheduleNextIfEnabled(SettingsRepository settingsRepository) async {
    try {
      final settings = await settingsRepository.getSettings();
      if (settings.pendingOrdersReminderEnabled) {
        await _scheduler.scheduleNextDay(settings.pendingOrdersReminderTime);
        AppLogger.info('Next pending orders reminder scheduled for tomorrow');
      }
    } catch (e) {
      AppLogger.error('Failed to schedule next reminder', e);
    }
  }

  static Future<PendingOrdersData> _aggregatePendingOrdersData({
    required OrderRepository orderRepository,
    required CustomerRepository customerRepository,
    required SettingsRepository settingsRepository,
  }) async {
    final settings = await settingsRepository.getSettings();
    final thresholdDays = settings.dueDateWarningThreshold;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thresholdDate = today.add(Duration(days: thresholdDays));

    final allOrders = await orderRepository.getAllOrders();
    final allCustomers = await customerRepository.getAllCustomers();

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
    await DatabaseService.initialize();
    await NotificationService.initialize();
  }
}
