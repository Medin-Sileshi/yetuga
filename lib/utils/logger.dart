import 'package:flutter/foundation.dart';

/// A simple logger utility that only logs in debug mode
class Logger {
  // Control whether debug logs are enabled
  static bool _debugLogsEnabled = true;

  // Maximum log message length to prevent memory issues
  static const int _maxLogLength = 1000;

  // Enable or disable debug logs
  static void setDebugLogsEnabled(bool enabled) {
    _debugLogsEnabled = enabled;
  }

  // Truncate long messages to prevent memory issues
  static String _truncateMessage(String message) {
    if (message.length > _maxLogLength) {
      return '${message.substring(0, _maxLogLength)}... (truncated)';
    }
    return message;
  }

  static void d(String tag, String message) {
    if (kDebugMode && _debugLogsEnabled) {
      debugPrint('DEBUG: [${_truncateMessage(tag)}] ${_truncateMessage(message)}');
    }
  }

  static void i(String tag, String message) {
    if (kDebugMode) {
      debugPrint('INFO: [${_truncateMessage(tag)}] ${_truncateMessage(message)}');
    }
  }

  static void w(String tag, String message) {
    if (kDebugMode) {
      debugPrint('WARN: [${_truncateMessage(tag)}] ${_truncateMessage(message)}');
    }
  }

  static void e(String tag, String message, [dynamic error]) {
    if (kDebugMode) {
      if (error != null) {
        debugPrint('ERROR: [${_truncateMessage(tag)}] ${_truncateMessage(message)} - $error');
      } else {
        debugPrint('ERROR: [${_truncateMessage(tag)}] ${_truncateMessage(message)}');
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