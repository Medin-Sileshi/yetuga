import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/auth_guard.dart';
import 'home_screen.dart';

/// Wrapper for HomeScreen that ensures the user is authenticated
class AuthenticatedHomeScreen extends ConsumerWidget {
  const AuthenticatedHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AuthGuard(
      child: HomeScreen(),
    );
  }
}
