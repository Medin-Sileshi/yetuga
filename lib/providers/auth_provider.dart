import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../utils/logger.dart';

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(const AsyncValue.loading()) {
    _auth.authStateChanges().listen((user) {
      Logger.d('AuthProvider',
          "Auth state changed: ${user != null ? 'User logged in' : 'No user'}");
      state = AsyncValue.data(user);
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      Logger.d('AuthProvider', 'Attempting email sign in: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.d('AuthProvider', 'Email sign in successful: ${userCredential.user?.uid}');
      state = AsyncValue.data(userCredential.user);

      // Check for unread notifications and send push notifications
      // This will be handled by the AuthService's signInWithEmail method
    } catch (e, st) {
      Logger.d('AuthProvider', 'Email sign in failed: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> createAccount(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      Logger.d('AuthProvider', 'Attempting to create account: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.d('AuthProvider', 'Account creation successful: ${userCredential.user?.uid}');
      state = AsyncValue.data(userCredential.user);
    } catch (e, st) {
      Logger.d('AuthProvider', 'Account creation failed: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle(WidgetRef ref) async {
    try {
      state = const AsyncValue.loading();
      Logger.d('AuthProvider', 'Starting Google sign in process');
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();

      if (userCredential == null) {
        Logger.d('AuthProvider', 'Google sign in was canceled by user');
        state = const AsyncValue.data(null);
        return;
      }

      Logger.d('AuthProvider', 'Google sign in successful: ${userCredential.user?.uid}');
      state = AsyncValue.data(userCredential.user);
    } catch (e, st) {
      Logger.d('AuthProvider', 'Google sign in failed: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut(WidgetRef ref) async {
    try {
      state = const AsyncValue.loading();
      Logger.d('AuthProvider', 'Starting sign out process');
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      Logger.d('AuthProvider', 'Sign out successful');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      Logger.e('AuthProvider', 'Error during sign out', e);
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      state = const AsyncValue.loading();
      Logger.d('AuthProvider', 'Attempting to send password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      Logger.d('AuthProvider', 'Password reset email sent successfully');
    } catch (e, st) {
      Logger.d('AuthProvider', 'Password reset failed: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

// Note: AuthService provider is now defined in auth_service.dart

// Stream provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref
      .watch(authStateProvider)
      .when(data: (user) => user, loading: () => null, error: (_, __) => null);
});
