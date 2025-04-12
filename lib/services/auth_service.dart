import 'package:firebase_auth/firebase_auth.dart';
import 'google_sign_in_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      return await googleSignInService.signInWithGoogle();
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Email sign in successful: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('Error signing in with email: $e');
      rethrow;
    }
  }

  // Create account with email and password
  Future<UserCredential> createAccount(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Account created successfully: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      print('Error creating account: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('Password reset email sent to: $email');
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in with Google
      try {
        await googleSignInService.signOut();
      } catch (e) {
        print('Error signing out from Google: $e');
        // Continue with Firebase sign out even if Google sign out fails
      }

      // Sign out from Firebase
      await _auth.signOut();
      print('User signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
}

// Singleton instance
final authService = AuthService();
