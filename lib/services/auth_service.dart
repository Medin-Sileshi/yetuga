import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import 'google_sign_in_service.dart';
import 'notification_service.dart';

// Provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final notificationService = ref.read(notificationServiceProvider);
  return AuthService(notificationService);
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService;

  AuthService(this._notificationService);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final userCredential = await googleSignInService.signInWithGoogle();

      // Check for unread notifications and send push notifications
      if (userCredential != null) {
        _checkForUnreadNotifications();
      }

      return userCredential;
    } catch (e) {
      Logger.e('AuthService', 'Error signing in with Google', e);
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
      Logger.d('AuthService', 'Email sign in successful: ${userCredential.user?.email}');

      // Check for unread notifications and send push notifications
      _checkForUnreadNotifications();

      return userCredential;
    } catch (e) {
      Logger.e('AuthService', 'Error signing in with email', e);
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
      Logger.d('AuthService', 'Account created successfully: ${userCredential.user?.email}');
      return userCredential;
    } catch (e) {
      Logger.e('AuthService', 'Error creating account', e);
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Logger.d('AuthService', 'Password reset email sent to: $email');
    } catch (e) {
      Logger.e('AuthService', 'Error sending password reset email', e);
      rethrow;
    }
  }

  // Helper method to check for unread notifications
  Future<void> _checkForUnreadNotifications() async {
    try {
      // Wait a short time to ensure Firebase auth state is fully updated
      await Future.delayed(const Duration(seconds: 1));

      // Check for unread notifications and send push notifications
      await _notificationService.checkAndSendUnreadNotifications();
    } catch (e) {
      Logger.e('AuthService', 'Error checking for unread notifications', e);
      // Don't rethrow - this should not interrupt the login flow
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in with Google
      try {
        await googleSignInService.signOut();
      } catch (e) {
        Logger.e('AuthService', 'Error signing out from Google', e);
        // Continue with Firebase sign out even if Google sign out fails
      }

      // Sign out from Firebase
      await _auth.signOut();
      Logger.d('AuthService', 'User signed out successfully');
    } catch (e) {
      Logger.e('AuthService', 'Error signing out', e);
      rethrow;
    }
  }
}

// Note: We're now using the provider instead of a singleton instance
