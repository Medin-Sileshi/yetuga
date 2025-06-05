import 'package:flutter/material.dart';

class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void navigateTo(String routeName) {
    navigatorKey.currentState?.pushNamed(routeName);
  }

  void navigateToAuthScreen() {
    navigateTo('/auth');
  }

  void navigateToHomeScreen() {
    navigateTo('/home');
  }

  void navigateToOnboardingScreen() {
    navigateTo('/onboarding');
  }
}
