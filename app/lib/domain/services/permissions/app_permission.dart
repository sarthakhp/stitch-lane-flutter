/// The three runtime permissions this app cares about. Centralising the set
/// here means UI, controller, and the request batch all iterate the same list
/// — adding/removing a permission is a one-line change.
enum AppPermission { microphone, notification, contacts }

extension AppPermissionInfo on AppPermission {
  /// Short human-readable label (Title Case). Used in the explainer dialog
  /// and any per-permission UI rows.
  String get label => switch (this) {
        AppPermission.microphone => 'Microphone',
        AppPermission.notification => 'Notifications',
        AppPermission.contacts => 'Contacts',
      };

  /// One-line jargon-free rationale, written to a user (not a developer).
  /// Shown next to the label in the explainer dialog.
  String get rationale => switch (this) {
        AppPermission.microphone =>
          'Record audio notes for orders and customers.',
        AppPermission.notification =>
          'Remind you about pending orders and daily backups.',
        AppPermission.contacts =>
          'Import customers from your phone contacts.',
      };
}
