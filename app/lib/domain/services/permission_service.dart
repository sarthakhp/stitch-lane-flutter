import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_logger.dart';

class PermissionService {
  static bool _hasRequestedPermissions = false;

  static bool get hasRequestedPermissions => _hasRequestedPermissions;

  static Future<void> requestAllPermissions() async {
    if (_hasRequestedPermissions) return;
    if (kIsWeb) {
      _hasRequestedPermissions = true;
      return;
    }

    _hasRequestedPermissions = true;

    AppLogger.info('Requesting all permissions...');

    final permissions = <Permission>[
      Permission.microphone,
      Permission.notification,
    ];

    final statuses = await permissions.request();

    for (final entry in statuses.entries) {
      AppLogger.info('Permission ${entry.key}: ${entry.value}');
    }

    try {
      final contactsGranted = await FlutterContacts.requestPermission(readonly: true);
      AppLogger.info('Contacts permission: ${contactsGranted ? 'granted' : 'denied'}');
    } catch (e) {
      AppLogger.error('Failed to request contacts permission', e);
    }

    AppLogger.info('All permissions requested');
  }

  static Future<bool> hasMicrophonePermission() async {
    if (kIsWeb) return false;
    return await Permission.microphone.isGranted;
  }

  static Future<bool> hasNotificationPermission() async {
    if (kIsWeb) return true;
    return await Permission.notification.isGranted;
  }

  static Future<bool> hasContactsPermission() async {
    if (kIsWeb) return false;
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      return false;
    }
  }
}

