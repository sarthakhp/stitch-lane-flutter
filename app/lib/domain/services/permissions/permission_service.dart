import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import '../../../utils/app_logger.dart';
import 'app_permission.dart';
import 'app_permission_status.dart';

/// Stateless wrapper over `permission_handler`. Translates between our
/// [AppPermission] enum and the plugin's types, so the rest of the app never
/// imports `permission_handler` directly. Holding no state keeps it
/// trivially testable and means the [PermissionController] is the only place
/// state lives.
class PermissionService {
  PermissionService._();

  static const Map<AppPermission, Permission> _plugin = {
    AppPermission.microphone: Permission.microphone,
    AppPermission.notification: Permission.notification,
    AppPermission.contacts: Permission.contacts,
  };

  /// Current status of every permission, queried in parallel. On web every
  /// permission is reported "granted" — web doesn't expose these via
  /// `permission_handler` and the app's web build doesn't use them anyway.
  static Future<Map<AppPermission, AppPermissionStatus>> queryAll() async {
    if (kIsWeb) {
      return {
        for (final p in AppPermission.values)
          p: const AppPermissionStatus(granted: true, permanentlyDenied: false),
      };
    }
    final entries = await Future.wait(AppPermission.values.map((p) async {
      final status = await _plugin[p]!.status;
      return MapEntry(p, _toAppStatus(status));
    }));
    return Map.fromEntries(entries);
  }

  /// Fires the native dialogs for any permission that isn't already granted.
  /// Already-granted entries are skipped (no point re-prompting). Returns the
  /// post-request statuses so the caller can update state in one notify.
  static Future<Map<AppPermission, AppPermissionStatus>> requestAll() async {
    if (kIsWeb) return queryAll();

    final toRequest = <Permission>[];
    final pluginToEnum = <Permission, AppPermission>{};
    for (final entry in _plugin.entries) {
      final current = await entry.value.status;
      if (!current.isGranted) {
        toRequest.add(entry.value);
        pluginToEnum[entry.value] = entry.key;
      }
    }

    if (toRequest.isNotEmpty) {
      AppLogger.info('Requesting ${toRequest.length} permission(s)');
      final results = await toRequest.request();
      for (final entry in results.entries) {
        AppLogger.info('  ${pluginToEnum[entry.key]}: ${entry.value}');
      }
    }

    return queryAll();
  }

  /// Opens the OS-level app settings page. Used when one or more permissions
  /// are permanently denied and `request()` will no-op.
  static Future<bool> openSystemSettings() {
    if (kIsWeb) return Future.value(false);
    return openAppSettings();
  }

  /// Translate the plugin's broad enum down to the two booleans we care about.
  /// [PermissionStatus.limited] / [PermissionStatus.provisional] are treated as
  /// granted — they cover the capability for our needs (iOS partial-contacts,
  /// provisional notifications, etc.).
  static AppPermissionStatus _toAppStatus(PermissionStatus s) {
    final granted = s.isGranted || s.isLimited || s.isProvisional;
    return AppPermissionStatus(
      granted: granted,
      permanentlyDenied: s.isPermanentlyDenied,
    );
  }
}
