/// Canonical Firestore collection names for synced entities. These double as
/// the `collection` value stored in `sync_outbox` and the local table names,
/// so they must stay in lockstep with the SQLite schema.
class SyncCollections {
  SyncCollections._();

  static const String customers = 'customers';
  static const String orders = 'orders';
  static const String measurements = 'measurements';

  /// Every synced collection, in dependency order (parents before children) so
  /// a cold-start applier can create rows without tripping foreign keys.
  static const List<String> all = [customers, orders, measurements];
}

/// Keys for the `sync_meta` key/value table. One place to look so a typo can't
/// silently fork a key into two.
class SyncMetaKeys {
  SyncMetaKeys._();

  static const String syncEnabled = 'sync_enabled';
  static const String deviceId = 'device_id';
  static const String deviceName = 'device_name';
  static const String cachedControl = 'cached_control';
  static const String writerEpoch = 'writer_epoch';
  static const String lastPushAt = 'last_push_at';
  static const String lastPullAt = 'last_pull_at';
  static const String backfillDone = 'backfill_done';
}
