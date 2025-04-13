import 'package:firebase_auth/firebase_auth.dart';
import 'package:yetuga/utils/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  // Get Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize GoogleSignIn with proper configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  // Method to sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        Logger.d('GoogleSignInService', 'Google Sign In was canceled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Get the current user
      final User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        // User is already signed in, link the credential
        return await currentUser.linkWithCredential(credential);
      } else {
        // Sign in with the credential
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      Logger.e('GoogleSignInService', 'Error signing in with Google', e);
      rethrow;
    }
  }

  // Method to sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      Logger.d('GoogleSignInService', 'User signed out successfully');
    } catch (e) {
      Logger.e('GoogleSignInService', 'Error signing out', e);
      rethrow;
    }
  }
}

// Singleton instance
final googleSignInService = GoogleSignInService();
