import 'package:flutter/material.dart';

import '../domain/services/connectivity/connectivity_service.dart';

/// Pre-flight connectivity gate for features that need the network up front.
///
/// Runs a quick reachability probe and, when offline, surfaces a consistent
/// snackbar and tells the caller to abort. Keeps the "check then warn" pattern
/// in one place so every entry point behaves identically and the wording never
/// drifts.
class ConnectivityGuard {
  const ConnectivityGuard._();

  /// Returns `true` if the device is online and the caller should proceed.
  /// When offline, shows [ConnectivityService.offlineMessage] via the nearest
  /// [ScaffoldMessenger] and returns `false`.
  ///
  /// [service] is injectable for tests; defaults to the shared instance.
  static Future<bool> ensureOnline(
    BuildContext context, {
    ConnectivityService? service,
  }) async {
    final online =
        await (service ?? ConnectivityService.instance).hasInternet();
    if (online) return true;

    // The probe is async; the widget may be gone by the time it resolves.
    if (!context.mounted) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(ConnectivityService.offlineMessage)),
    );
    return false;
  }
}
