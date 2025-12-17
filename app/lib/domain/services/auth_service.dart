import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../config/auth_config.dart';
import '../state/auth_state.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AuthConfig.googleClientId,
  );

  static Future<void> signInWithGoogle(AuthState authState) async {
    try {
      authState.setLoading(true);
      authState.clearError();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        authState.setLoading(false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      authState.setUser(userCredential.user);
      authState.setLoading(false);
    } catch (e) {
      authState.setError('Failed to sign in with Google: ${e.toString()}');
    }
  }

  static Future<void> signOut(AuthState authState) async {
    try {
      authState.setLoading(true);
      authState.clearError();

      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      authState.signOut();
    } catch (e) {
      authState.setError('Failed to sign out: ${e.toString()}');
    }
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  static Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}

