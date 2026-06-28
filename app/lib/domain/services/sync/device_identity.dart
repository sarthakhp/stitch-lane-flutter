import 'package:uuid/uuid.dart';

import '../../../backend/repositories/sync_meta_repository.dart';
import 'sync_keys.dart';

/// Stable per-install identifier stored in sync_meta.
/// Survives app restarts; changes only on uninstall or sign-out (clearAll).
class DeviceIdentity {
  DeviceIdentity._();

  /// Returns the stable device id, generating and persisting one if absent.
  static Future<String> deviceId(SyncMetaRepository repo) async {
    final existing = await repo.get(SyncMetaKeys.deviceId);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await repo.set(SyncMetaKeys.deviceId, id);
    return id;
  }

  /// Returns the stored device name, or a default if not set.
  static Future<String> deviceName(SyncMetaRepository repo) async {
    return await repo.get(SyncMetaKeys.deviceName) ?? 'Device';
  }

  /// Persist a human-readable label for this device (shown in the writer
  /// control doc and the handoff UI).
  static Future<void> setDeviceName(
      SyncMetaRepository repo, String name) async {
    await repo.set(SyncMetaKeys.deviceName, name);
  }
}
