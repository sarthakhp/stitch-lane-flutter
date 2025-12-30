import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../../utils/app_logger.dart';
import '../models/notification_payload.dart';
import '../models/pending_orders_data.dart';

enum _NotificationChannel {
  backup(
    id: 'stitch_lane_backup',
    name: 'Backup Notifications',
    description: 'Notifications for automatic backup status',
  ),
  reminder(
    id: 'stitch_lane_reminders',
    name: 'Order Reminders',
    description: 'Daily reminders about pending orders',
  );

  final String id;
  final String name;
  final String description;

  const _NotificationChannel({
    required this.id,
    required this.name,
    required this.description,
  });
}

enum _NotificationId {
  backupFailed(1),
  backupSuccess(2),
  backupInProgress(3),
  pendingOrdersReminder(100);

  final int value;
  const _NotificationId(this.value);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static String? _pendingNotificationPayload;

  static Future<void> initialize() async {
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
    if (response.payload != null) {
      _pendingNotificationPayload = response.payload;
    }
  }

  static Future<void> _checkInitialNotification() async {
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) {
        _pendingNotificationPayload = payload;
      }
    }
  }

  static NotificationPayload? consumePendingPayload() {
    final payload = NotificationPayload.fromString(_pendingNotificationPayload);
    _pendingNotificationPayload = null;
    return payload;
  }

  static AndroidNotificationDetails _buildAndroidDetails(
    _NotificationChannel channel, {
    required Importance importance,
    required Priority priority,
    bool ongoing = false,
    bool showProgress = false,
    bool indeterminate = false,
    StyleInformation? styleInformation,
  }) {
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      ongoing: ongoing,
      showProgress: showProgress,
      indeterminate: indeterminate,
      styleInformation: styleInformation,
    );
  }

  static DarwinNotificationDetails _buildDarwinDetails({
    required bool presentAlert,
    required bool presentBadge,
    required bool presentSound,
  }) {
    return DarwinNotificationDetails(
      presentAlert: presentAlert,
      presentBadge: presentBadge,
      presentSound: presentSound,
    );
  }

  static NotificationDetails _buildNotificationDetails({
    required AndroidNotificationDetails android,
    required DarwinNotificationDetails darwin,
  }) {
    return NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  static Future<void> showBackupFailedNotification(String errorMessage) async {
    final androidDetails = _buildAndroidDetails(
      _NotificationChannel.backup,
      importance: Importance.high,
      priority: Priority.high,
    );
    final darwinDetails = _buildDarwinDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = _buildNotificationDetails(
      android: androidDetails,
      darwin: darwinDetails,
    );

    await _notifications.show(
      _NotificationId.backupFailed.value,
      'Auto-Backup Failed',
      errorMessage,
      details,
    );

    AppLogger.info('Backup failed notification shown: $errorMessage');
  }

  static Future<void> showBackupSuccessNotification() async {
    await cancelBackupInProgressNotification();

    final androidDetails = _buildAndroidDetails(
      _NotificationChannel.backup,
      importance: Importance.low,
      priority: Priority.low,
    );
    final darwinDetails = _buildDarwinDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );
    final details = _buildNotificationDetails(
      android: androidDetails,
      darwin: darwinDetails,
    );

    await _notifications.show(
      _NotificationId.backupSuccess.value,
      'Auto-Backup Complete',
      'Your data has been backed up to Google Drive',
      details,
    );

    AppLogger.info('Backup success notification shown');
  }

  static Future<void> showBackupInProgressNotification() async {
    final androidDetails = _buildAndroidDetails(
      _NotificationChannel.backup,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showProgress: true,
      indeterminate: true,
    );
    final darwinDetails = _buildDarwinDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );
    final details = _buildNotificationDetails(
      android: androidDetails,
      darwin: darwinDetails,
    );

    await _notifications.show(
      _NotificationId.backupInProgress.value,
      'Auto-Backup in Progress',
      'Backing up your data to Google Drive...',
      details,
    );

    AppLogger.info('Backup in progress notification shown');
  }

  static Future<void> cancelBackupInProgressNotification() async {
    await _notifications.cancel(_NotificationId.backupInProgress.value);
  }

  static Future<void> showPendingOrdersReminderNotification(
    PendingOrdersData data,
  ) async {
    final title = '${data.totalPendingOrders} Pending Orders from ${data.customerCount} customers';
    final body = _formatPendingOrdersBody(data);

    final androidDetails = _buildAndroidDetails(
      _NotificationChannel.reminder,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Tap to view customers',
      ),
    );
    final darwinDetails = _buildDarwinDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = _buildNotificationDetails(
      android: androidDetails,
      darwin: darwinDetails,
    );

    await _notifications.show(
      _NotificationId.pendingOrdersReminder.value,
      title,
      body,
      details,
      payload: NotificationPayload.pendingOrdersReminder.value,
    );

    AppLogger.info('Pending orders reminder notification shown: ${data.totalPendingOrders} orders');
  }

  static Future<void> showNoPendingOrdersNotification() async {
    final androidDetails = _buildAndroidDetails(
      _NotificationChannel.reminder,
      importance: Importance.low,
      priority: Priority.low,
    );
    final darwinDetails = _buildDarwinDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );
    final details = _buildNotificationDetails(
      android: androidDetails,
      darwin: darwinDetails,
    );

    await _notifications.show(
      _NotificationId.pendingOrdersReminder.value,
      'No Pending Orders Due Soon',
      'All caught up! No orders due within the threshold.',
      details,
      payload: NotificationPayload.pendingOrdersReminder.value,
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

