abstract class SyncMetaRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<void> remove(String key);

  /// Called during sign-out to wipe all sync metadata from this device.
  Future<void> clearAll();
}
