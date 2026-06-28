/// Feature flag for multi-device sync. Defaults to false (disabled).
///
/// Call [init] at startup (after the DB is ready) to read the persisted value
/// from sync_meta. Without calling [init], the feature is always off — which
/// is the safe default while any phase of the sync build is in progress.
class SyncConfig {
  SyncConfig._();

  static bool _enabled = false;

  static bool get enabled => _enabled;

  /// Initialise from the persisted setting. [getValue] should read the
  /// `sync_enabled` key from the sync_meta table (value '1' = enabled).
  static Future<void> init(Future<String?> Function(String key) getValue) async {
    final raw = await getValue('sync_enabled');
    _enabled = raw == '1';
  }

  /// For tests or explicit enable/disable in the settings UI.
  static void setEnabled(bool value) => _enabled = value;
}
