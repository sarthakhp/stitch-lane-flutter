import 'dart:convert';

/// Thrown when a backup would overwrite the cloud copy with an empty dataset
/// (zero customers AND zero orders). This protects against the classic
/// data-loss footgun: a fresh sign-in / reinstall starts with an empty local
/// database, and an auto- or manual backup firing before any data exists would
/// clobber the good Drive backup with nothing.
///
/// This is NOT a failure — callers should treat it as "skipped, nothing to back
/// up" (auto-backup) or a gentle nudge (manual backup), never as an error.
class EmptyBackupException implements Exception {
  const EmptyBackupException();

  @override
  String toString() =>
      'EmptyBackupException: refusing to back up an empty dataset '
      '(0 customers and 0 orders) — the existing backup is left untouched.';
}

/// The single source of truth for "is this dataset too empty to back up?".
///
/// The rule lives here so the early UX checks (auto/manual backup runners) and
/// the hard last-line-of-defense inside `DriveService.uploadBackup` all agree.
/// It deliberately does NOT touch the local zip export path: exporting an empty
/// dataset to a user-named file can't overwrite anything, so it stays allowed.
class BackupGuard {
  const BackupGuard._();

  /// True when there's nothing worth backing up: no customers AND no orders.
  /// Measurements hang off customers/orders, so this pair is sufficient.
  static bool isEmpty(int customerCount, int orderCount) =>
      customerCount == 0 && orderCount == 0;

  /// Reads the customer/order counts embedded in a backup JSON payload (under
  /// `metadata.customerCount` / `metadata.orderCount`, written by
  /// `BackupService.createBackup`) and reports whether it's an empty backup.
  ///
  /// Fail-OPEN by design: if the metadata is missing or the payload can't be
  /// parsed we return `false` (treat as non-empty) so a format change can never
  /// silently block legitimate backups. We only block when we can POSITIVELY
  /// confirm both counts are present and both zero.
  static bool isEmptyBackupJson(String backupJson) {
    try {
      final data = jsonDecode(backupJson);
      if (data is! Map<String, dynamic>) return false;
      final metadata = data['metadata'];
      if (metadata is! Map<String, dynamic>) return false;

      final customerCount = metadata['customerCount'];
      final orderCount = metadata['orderCount'];
      // Both counts must be explicitly present to make a confident call.
      if (customerCount is! num || orderCount is! num) return false;

      return isEmpty(customerCount.toInt(), orderCount.toInt());
    } catch (_) {
      return false;
    }
  }
}
