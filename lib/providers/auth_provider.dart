import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthNotifier() : super(const AsyncValue.loading()) {
    _auth.authStateChanges().listen((user) {
      print(
          "Auth state changed: ${user != null ? 'User logged in' : 'No user'}");
      state = AsyncValue.data(user);
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      print("Attempting email sign in: $email");
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("Email sign in successful: ${userCredential.user?.uid}");
      state = AsyncValue.data(userCredential.user);
    } catch (e, st) {
      print("Email sign in failed: $e");
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> createAccount(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      print("Attempting to create account: $email");
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("Account creation successful: ${userCredential.user?.uid}");
      state = AsyncValue.data(userCredential.user);
    } catch (e, st) {
      print("Account creation failed: $e");
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = const AsyncValue.loading();
      print("Starting Google sign in process");
      final userCredential = await authService.signInWithGoogle();

      if (userCredential == null) {
        print("Google sign in was canceled by user");
        state = const AsyncValue.data(null);
        return;
      }

      print("Google sign in successful: ${userCredential.user?.uid}");
      state = AsyncValue.data(userCredential.user);
    } catch (e, st) {
      print("Google sign in failed: $e");
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      state = const AsyncValue.loading();
      print("Starting sign out process");
      await authService.signOut();
      print("Sign out successful");
      state = const AsyncValue.data(null);
    } catch (e, st) {
      print("Error during sign out: $e");
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      state = const AsyncValue.loading();
      print("Attempting to send password reset email to: $email");
      await _auth.sendPasswordResetEmail(email: email);
      print("Password reset email sent successfully");
    } catch (e, st) {
      print("Password reset failed: $e");
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier();
});

// Provider for AuthService instance
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

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
