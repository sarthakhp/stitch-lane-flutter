import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_logger.dart';

/// Durable "this device still owes itself a media download after a restore"
/// flag, stored in shared_preferences so it survives app kills and reboots.
///
/// It is only a hint that lets startup skip hitting Drive once hydration is
/// known-complete — correctness comes from [MediaHydrationService] recomputing
/// the missing set from durable facts (the DB + the Drive folder), so even a
/// wrong flag never loses or deletes data. Set when a restore finishes writing
/// the database; cleared only after a hydration pass downloads everything.
class RestoreMediaState {
  RestoreMediaState._();

  static const String _key = 'restore_media_hydration_pending';

  static Future<void> markPending() => _set(true);

  static Future<void> clearPending() => _set(false);

  static Future<bool> isPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (e) {
      // Fail closed: if we can't read the flag, don't claim work is pending.
      AppLogger.warning('[RestoreMediaState] read failed: $e');
      return false;
    }
  }

  static Future<void> _set(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (e) {
      AppLogger.warning('[RestoreMediaState] write($value) failed: $e');
    }
  }
}
