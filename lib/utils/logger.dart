import 'package:flutter/foundation.dart';

/// A simple logger utility that only logs in debug mode
class Logger {
  static void d(String tag, String message) {
    if (kDebugMode) {
      print('DEBUG: [$tag] $message');
    }
  }

  static void i(String tag, String message) {
    if (kDebugMode) {
      print('INFO: [$tag] $message');
    }
  }

  static void w(String tag, String message) {
    if (kDebugMode) {
      print('WARN: [$tag] $message');
    }
  }

  static void e(String tag, String message, [dynamic error]) {
    if (kDebugMode) {
      if (error != null) {
        print('ERROR: [$tag] $message - $error');
      } else {
        print('ERROR: [$tag] $message');
      }
    }
  }

  // Backward compatibility methods
  static void info(String message) {
    i('App', message);
  }

  static void error(String message, [dynamic error]) {
    e('App', message, error);
  }
}