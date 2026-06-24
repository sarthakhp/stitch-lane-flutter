import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'auth_service.dart';
import '../../utils/app_logger.dart';

/// Why Google Drive can't be used without an interactive sign-in.
enum DriveAuthReason {
  /// No usable Google account locally — silent sign-in returned nothing.
  needsReauth,

  /// A Google account exists but its Drive token is expired or revoked.
  expired,
}

/// Raised when Google Drive needs an *interactive* re-consent before it can be
/// used. The recovery is [DriveAuthService.reconnect] — NOT a plain retry,
/// which would just hit the same dead credentials and fail identically.
class DriveAuthException implements Exception {
  final DriveAuthReason reason;
  const DriveAuthException(this.reason);

  /// User-facing, jargon-free explanation.
  String get message => switch (reason) {
        DriveAuthReason.needsReauth =>
          'Google Drive needs you to sign in again to keep backing up.',
        DriveAuthReason.expired =>
          'Google Drive access expired — sign in again to keep backing up.',
      };

  // The stable "DriveAuthException" prefix is what [matches] keys off once the
  // error has been persisted as a string (settings.lastBackupError). We own
  // this text, so — unlike raw Google SDK messages — it won't drift between
  // versions, which makes the classification reliable rather than brittle.
  @override
  String toString() => 'DriveAuthException: $message';

  /// Whether a persisted backup-error string came from a Drive re-auth failure,
  /// so the UI can offer "Sign in & back up" instead of a doomed plain retry.
  static bool matches(String? errorText) =>
      errorText != null && errorText.contains('DriveAuthException');
}

/// Owns Google **Drive** connectivity, and ONLY that. Kept deliberately
/// separate from [AuthService] (which owns the app/Firebase identity) so the
/// two can never be confused:
///
///   * Reconnecting Drive can NEVER sign the user out of the app or wipe local
///     data. This class does not call `FirebaseAuth.signOut()` and does not
///     touch the local databases/files. Losing the Drive grant is a recoverable
///     inconvenience, not a logout. (Contrast [AuthService.signOut], which is
///     the one explicit, user-initiated nuke.)
///   * The only intended coupling runs the OTHER way: app sign-in
///     ([AuthService.signInWithGoogle]) also grants Drive, because both ride on
///     the single Google account on the device. This class operates on that
///     shared account via [AuthService.googleSignIn] but only ever performs
///     Google/Drive-scoped operations (signInSilently / signIn / signOut),
///     never app-identity ones.
class DriveAuthService {
  const DriveAuthService._();

  /// Build an authenticated Drive client, refreshing silently when possible.
  /// Throws [DriveAuthException] when only an interactive [reconnect] can fix
  /// it; throws other exceptions for unrelated failures (e.g. web popup).
  static Future<drive.DriveApi> getDriveApi() async {
    try {
      AppLogger.info('Acquiring Drive API access...');

      // Drive is gated on having an app session, but we only READ the Firebase
      // user here — we never sign it out.
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        throw Exception('User not authenticated');
      }

      final googleSignIn = AuthService.googleSignIn;
      var account = googleSignIn.currentUser;
      account ??= await googleSignIn.signInSilently();

      if (account == null) {
        AppLogger.warning('Drive: no Google account available — needs re-auth');
        throw const DriveAuthException(DriveAuthReason.needsReauth);
      }

      final authClient = await googleSignIn.authenticatedClient();
      if (authClient == null) {
        AppLogger.warning('Drive: token expired/revoked — needs re-auth');
        throw const DriveAuthException(DriveAuthReason.expired);
      }

      AppLogger.info('Drive API access acquired (${account.email})');
      return drive.DriveApi(authClient);
    } catch (e) {
      if (e is DriveAuthException) rethrow;
      AppLogger.error('Drive API error', e);
      if (e.toString().contains('popup_failed_to_open')) {
        throw Exception(
            'Please allow popups for this site and try again. Check your browser settings.');
      }
      rethrow;
    }
  }

  /// Lightweight "is Drive usable right now?" check — silent only, never
  /// prompts the user.
  static Future<bool> isConnected() async {
    final googleSignIn = AuthService.googleSignIn;
    if (googleSignIn.currentUser != null) return true;
    final account = await googleSignIn.signInSilently();
    return account != null;
  }

  /// Re-establish the Google **Drive** grant via an INTERACTIVE sign-in.
  ///
  /// Safe by construction: it resets only the Google account grant and never
  /// calls `FirebaseAuth.signOut()` or clears local data, so the app session is
  /// untouched even if the user cancels the Google prompt.
  ///
  /// Returns true once Drive is verified usable, false if the user cancelled or
  /// it still failed.
  static Future<bool> reconnect() async {
    final googleSignIn = AuthService.googleSignIn;
    try {
      // Drop the cached Google account so a stale/revoked grant can't simply be
      // handed back — this forces a fresh consent. It is a GOOGLE sign-out, NOT
      // an app (Firebase) sign-out: the app session stays intact.
      await googleSignIn.signOut();

      final account = await googleSignIn.signIn();
      if (account == null) {
        AppLogger.info('Drive reconnect cancelled by user — app session intact');
        return false;
      }

      // Verify the grant actually works now (also surfaces a still-bad token).
      await getDriveApi();
      AppLogger.info('Drive reconnected (${account.email})');
      return true;
    } catch (e) {
      AppLogger.error('Drive reconnect failed', e);
      return false;
    }
  }
}
