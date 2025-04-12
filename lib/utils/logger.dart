import 'package:flutter/foundation.dart';

class Logger {
  static void info(String message) {
    if (kDebugMode) {
      print('INFO: $message');
    }
  }

  static void error(String message, [dynamic error]) {
    if (kDebugMode) {
      print('ERROR: $message');
      if (error != null) {
        print('Error details: $error');
      }
    }
  }
}