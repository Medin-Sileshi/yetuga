import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service that provides global navigation capabilities
/// This allows navigation from services and other non-widget classes
final globalNavigationServiceProvider = Provider<GlobalNavigationService>((ref) {
  return GlobalNavigationService();
});

class GlobalNavigationService {
  /// Global navigator key to access the navigator from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigate to a named route
  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }

  /// Navigate to a route and remove all previous routes
  Future<dynamic> navigateToAndRemoveUntil(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }

  /// Navigate to a route using MaterialPageRoute
  Future<dynamic> navigateToRoute(Widget route) {
    return navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (context) => route),
    );
  }

  /// Pop the current route
  void goBack() {
    return navigatorKey.currentState!.pop();
  }

  /// Check if we can go back
  bool canGoBack() {
    return navigatorKey.currentState!.canPop();
  }
}
