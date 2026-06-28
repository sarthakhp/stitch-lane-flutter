import 'dart:convert';

import '../../../backend/repositories/sqlite_sync_meta_repository.dart';
import '../../../backend/repositories/sync_meta_repository.dart';
import 'control_doc.dart';
import 'sync_keys.dart';

/// The single source of truth for "may THIS device write to Google Drive?".
///
/// Drive holds the canonical cloud copy of the dataset — the backup blob plus
/// synced media. Only one device may author it: the sync writer (or a
/// sole-owner device with sync switched off, i.e. legacy behaviour). A reader
/// is a derived replica — possibly stale, with media only lazily downloaded —
/// so letting it write would clobber the writer's authoritative copy.
///
/// Every Drive *write* path shares this rule: media push/prune
/// ([SyncMediaPolicy]) and cloud backup (auto + manual). The check reads
/// `sync_meta` directly (not [SyncState]) so it also works inside the
/// WorkManager background isolate, where the provider tree doesn't exist.
class SyncDriveAuthority {
  SyncDriveAuthority._();

  /// True when this device may write to Drive:
  ///   • sync is disabled — sole-owner / legacy behaviour, unchanged from today; or
  ///   • sync is enabled and this device is the current writer.
  ///
  /// Returns false for a reader and for any unknown/ambiguous state, so the
  /// safe default is "don't touch Drive".
  static Future<bool> canWriteDrive({SyncMetaRepository? meta}) async {
    final repo = meta ?? SqliteSyncMetaRepository();

    final enabled = (await repo.get(SyncMetaKeys.syncEnabled)) == '1';
    if (!enabled) return true;

    final deviceId = await repo.get(SyncMetaKeys.deviceId);
    final cachedControl = await repo.get(SyncMetaKeys.cachedControl);
    if (deviceId == null || cachedControl == null) return false;

    try {
      final control = ControlDoc.fromMap(
          jsonDecode(cachedControl) as Map<String, dynamic>);
      return control?.writerDeviceId == deviceId;
    } catch (_) {
      return false;
    }
  }
}
