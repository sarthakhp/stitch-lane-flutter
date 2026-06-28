import '../../../backend/repositories/sync_meta_repository.dart';
import 'sync_drive_authority.dart';

/// Decides whether THIS device may push or prune media on Google Drive.
///
/// Drive media (images + audio) is owned by the writer. A reader only ever
/// *downloads* media lazily on view — it must never upload or, critically,
/// delete Drive files, or it could wipe media the writer still references.
///
/// Media push/prune is just one kind of Drive write, so it defers to the
/// shared [SyncDriveAuthority] rule (which also governs cloud backup) rather
/// than duplicating the writer check.
class SyncMediaPolicy {
  SyncMediaPolicy._();

  /// True when this device may upload/prune Drive media. See
  /// [SyncDriveAuthority.canWriteDrive] for the exact rule.
  static Future<bool> canManageDriveMedia({SyncMetaRepository? meta}) =>
      SyncDriveAuthority.canWriteDrive(meta: meta);
}
