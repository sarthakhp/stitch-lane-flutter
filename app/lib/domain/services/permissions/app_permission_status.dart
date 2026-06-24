/// A normalised snapshot of one Android permission's state, with only the bits
/// the app actually branches on. Keeping this distinct from `permission_handler`'s
/// own `PermissionStatus` keeps the domain free of plugin types and means callers
/// don't have to learn the (large) plugin enum just to ask "is it granted?".
class AppPermissionStatus {
  /// True when Android will let us use the capability right now.
  final bool granted;

  /// True when the user picked "Don't ask again" (or equivalent). In this case
  /// `request()` will silently no-op — the only recovery is system settings.
  final bool permanentlyDenied;

  const AppPermissionStatus({
    required this.granted,
    required this.permanentlyDenied,
  });

  /// Convenience for the unknown-yet-to-be-queried state. Treated as
  /// "not granted, can still ask" — safe default.
  static const AppPermissionStatus unknown =
      AppPermissionStatus(granted: false, permanentlyDenied: false);
}
