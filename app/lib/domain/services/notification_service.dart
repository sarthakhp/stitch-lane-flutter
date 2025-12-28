import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../../utils/app_logger.dart';
import '../models/pending_orders_data.dart';

const String pendingOrdersReminderPayload = 'pending_orders_reminder';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _backupChannelId = 'stitch_lane_backup';
  static const String _backupChannelName = 'Backup Notifications';
  static const String _backupChannelDescription = 'Notifications for automatic backup status';

  static const String _reminderChannelId = 'stitch_lane_reminders';
  static const String _reminderChannelName = 'Order Reminders';
  static const String _reminderChannelDescription = 'Daily reminders about pending orders';

  static const int _pendingOrdersNotificationId = 100;

  static void Function(String?)? _onNotificationTap;

  static Future<void> initialize({
    void Function(String?)? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    await _checkInitialNotification();

    AppLogger.info('NotificationService initialized');
  }

  static void _onDidReceiveNotificationResponse(
    NotificationResponse response,
  ) {
    AppLogger.info('Notification tapped with payload: ${response.payload}');
    _onNotificationTap?.call(response.payload);
  }

  static Future<void> _checkInitialNotification() async {
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      AppLogger.info('App launched from notification with payload: $payload');
      if (payload != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _onNotificationTap?.call(payload);
        });
      }
    }
  }

  static Future<void> showBackupFailedNotification(String errorMessage) async {
    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      _backupChannelName,
      channelDescription: _backupChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      1,
      'Auto-Backup Failed',
      errorMessage,
      details,
    );

    AppLogger.info('Backup failed notification shown: $errorMessage');
  }

  static Future<void> showBackupSuccessNotification() async {
    await cancelBackupInProgressNotification();

    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      _backupChannelName,
      channelDescription: _backupChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      2,
      'Auto-Backup Complete',
      'Your data has been backed up to Google Drive',
      details,
    );

    AppLogger.info('Backup success notification shown');
  }

  static Future<void> showBackupInProgressNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _backupChannelId,
      _backupChannelName,
      channelDescription: _backupChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      ongoing: true,
      showProgress: true,
      indeterminate: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      3,
      'Auto-Backup in Progress',
      'Backing up your data to Google Drive...',
      details,
    );

    AppLogger.info('Backup in progress notification shown');
  }

  static Future<void> cancelBackupInProgressNotification() async {
    await _notifications.cancel(3);
  }

  static Future<void> showPendingOrdersReminderNotification(
    PendingOrdersData data,
  ) async {
    final title = '${data.totalPendingOrders} Pending Orders from ${data.customerCount} customers';
    final body = _formatPendingOrdersBody(data);

    final androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: _reminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Tap to view customers',
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      _pendingOrdersNotificationId,
      title,
      body,
      details,
      payload: pendingOrdersReminderPayload,
    );

    AppLogger.info('Pending orders reminder notification shown: ${data.totalPendingOrders} orders');
  }

  static Future<void> showNoPendingOrdersNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      _reminderChannelName,
      channelDescription: _reminderChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(
      _pendingOrdersNotificationId,
      'No Pending Orders Due Soon',
      'All caught up! No orders due within the threshold.',
      details,
      payload: pendingOrdersReminderPayload,
    );

    AppLogger.info('No pending orders notification shown');
  }

  static String _formatPendingOrdersBody(PendingOrdersData data) {
    final dateFormat = DateFormat('MMM d');
    final lines = data.customers.map((customer) {
      final dueDateStr = dateFormat.format(customer.nearestDueDate);
      final readyInfo = customer.readyOrderCount > 0
          ? ', ${customer.readyOrderCount} ready'
          : '';
      return '${customer.customerName}: ${customer.pendingOrderCount} pending$readyInfo (Due: $dueDateStr)';
    });
    return lines.join('\n');
  }
}

