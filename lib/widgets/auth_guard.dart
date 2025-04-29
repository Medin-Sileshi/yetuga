import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/auth/auth_screen.dart';
import '../utils/logger.dart';

/// A widget that ensures the user is authenticated before showing its child.
/// If the user is not authenticated, it redirects to the AuthScreen.
class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      Logger.d('AuthGuard', 'User not authenticated, redirecting to auth screen');
      
      // Use a post-frame callback to avoid build-time navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      });
      
      // Return a loading indicator while redirecting
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // User is authenticated, show the child widget
    return child;
  }
}
