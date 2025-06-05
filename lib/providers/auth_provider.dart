import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../utils/logger.dart';

class AuthState {
  final bool isLoading;
  final String? error;
  final bool isSyncing;

  AuthState({this.isLoading = true, this.error, this.isSyncing = false});
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(AuthState()) {
    _auth.authStateChanges().listen((user) {
      Logger.d('AuthProvider',
          "Auth state changed: ${user != null ? 'User logged in: ${user.uid}' : 'No user'}");

      if (user != null) {
        // Force a reload of the user to ensure we have the latest data
        user.reload().then((_) {
          // Get the refreshed user
          final refreshedUser = _auth.currentUser;
          Logger.d('AuthProvider', 'User reloaded: ${refreshedUser?.uid}');
          state = AuthState(isLoading: false, error: null, isSyncing: false);
        }).catchError((error) {
          Logger.e('AuthProvider', 'Error reloading user', error);
          // Still update the state with the original user
          state = AuthState(isLoading: false, error: null, isSyncing: false);
        });
      } else {
        state = AuthState(isLoading: false, error: null, isSyncing: false);
      }
    });
  }

  void setLoading(bool isLoading) {
    state = AuthState(isLoading: isLoading, error: state.error, isSyncing: state.isSyncing);
  }

  void setError(String? error) {
    state = AuthState(isLoading: state.isLoading, error: error, isSyncing: state.isSyncing);
  }

  void setSyncing(bool isSyncing) {
    state = AuthState(isLoading: state.isLoading, error: state.error, isSyncing: isSyncing);
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      setLoading(true);
      Logger.d('AuthProvider', 'Attempting email sign in: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.d('AuthProvider', 'Email sign in successful: ${userCredential.user?.uid}');
      state = AuthState(isLoading: false, error: null, isSyncing: false);

      // Check for unread notifications and send push notifications
      // This will be handled by the AuthService's signInWithEmail method
    } catch (e) {
      Logger.d('AuthProvider', 'Email sign in failed: $e');
      state = AuthState(isLoading: false, error: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<void> createAccount(String email, String password) async {
    try {
      setLoading(true);
      Logger.d('AuthProvider', 'Attempting to create account: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      Logger.d('AuthProvider', 'Account creation successful: ${userCredential.user?.uid}');
      state = AuthState(isLoading: false, error: null, isSyncing: false);
    } catch (e) {
      Logger.d('AuthProvider', 'Account creation failed: $e');
      state = AuthState(isLoading: false, error: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<void> signInWithGoogle(WidgetRef ref) async {
    try {
      setLoading(true);
      Logger.d('AuthProvider', 'Starting Google sign in process');
      final authService = ref.read(authServiceProvider);
      final userCredential = await authService.signInWithGoogle();

      if (userCredential == null) {
        Logger.d('AuthProvider', 'Google sign in was canceled by user');
        state = AuthState(isLoading: false, error: null, isSyncing: false);
        return;
      }

      Logger.d('AuthProvider', 'Google sign in successful: ${userCredential.user?.uid}');
      state = AuthState(isLoading: false, error: null, isSyncing: false);
    } catch (e) {
      Logger.d('AuthProvider', 'Google sign in failed: $e');
      state = AuthState(isLoading: false, error: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<void> signOut(WidgetRef ref) async {
    try {
      // Get the current user ID before signing out
      final currentUserId = _auth.currentUser?.uid;
      Logger.d('AuthProvider', 'Starting sign out process for user: $currentUserId');

      // Set state to loading
      setLoading(true);

      // Clear all caches before signing out
      if (currentUserId != null) {
        try {
          // We'll handle this in the auth_service.dart file
          Logger.d('AuthProvider', 'Skipping onboarding provider state clearing in AuthProvider');
        } catch (e) {
          Logger.e('AuthProvider', 'Error in auth provider', e);
        }
      }

      // Sign out using auth service
      final authService = ref.read(authServiceProvider);
      await authService.signOut();

      // Force a reload of Firebase Auth
      try {
        await FirebaseAuth.instance.signOut();
        Logger.d('AuthProvider', 'Forced Firebase Auth reload');
      } catch (e) {
        Logger.e('AuthProvider', 'Error forcing Firebase Auth reload', e);
      }

      Logger.d('AuthProvider', 'Sign out successful');
      state = AuthState(isLoading: false, error: null, isSyncing: false);
    } catch (e) {
      Logger.e('AuthProvider', 'Error during sign out', e);
      state = AuthState(isLoading: false, error: e.toString(), isSyncing: false);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      setLoading(true);
      Logger.d('AuthProvider', 'Attempting to send password reset email to: $email');
      await _auth.sendPasswordResetEmail(email: email);
      Logger.d('AuthProvider', 'Password reset email sent successfully');
    } catch (e) {
      Logger.d('AuthProvider', 'Password reset failed: $e');
      state = AuthState(isLoading: false, error: e.toString(), isSyncing: false);
      rethrow;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
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
