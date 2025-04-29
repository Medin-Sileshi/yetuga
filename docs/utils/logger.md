# Logger Utility Documentation

## Overview

The `Logger` class provides a simple, consistent logging utility for the Yetu'ga application. It's designed to facilitate debugging during development while preventing excessive logging in production environments.

## Features

- **Debug-Only Logging**: Logs are only displayed in debug mode
- **Log Levels**: Supports different log levels (debug, info, warning, error)
- **Tagged Logging**: Organizes logs by component/tag
- **Message Truncation**: Prevents memory issues with large log messages
- **Error Context**: Includes error objects in error logs
- **Configurable**: Debug logs can be enabled/disabled at runtime

## Usage

### Basic Usage

```dart
// Debug log
Logger.d('ComponentName', 'This is a debug message');

// Info log
Logger.i('ComponentName', 'This is an info message');

// Warning log
Logger.w('ComponentName', 'This is a warning message');

// Error log
try {
  // Some operation that might throw
} catch (e) {
  Logger.e('ComponentName', 'Operation failed', e);
}
```

### Backward Compatibility Methods

```dart
// Simple info log (uses 'App' as the tag)
Logger.info('This is an info message');

// Simple error log (uses 'App' as the tag)
Logger.error('This is an error message', someException);
```

### Enabling/Disabling Debug Logs

```dart
// Disable debug logs (info, warning, and error logs will still be shown)
Logger.setDebugLogsEnabled(false);

// Enable debug logs
Logger.setDebugLogsEnabled(true);
```

## Implementation Details

### Log Format

Logs are formatted as:
```
LEVEL: [TAG] MESSAGE
```

For errors with an exception:
```
ERROR: [TAG] MESSAGE - EXCEPTION
```

### Message Truncation

To prevent memory issues with very large log messages, the Logger automatically truncates messages longer than 1000 characters:

```dart
static String _truncateMessage(String message) {
  if (message.length > _maxLogLength) {
    return '${message.substring(0, _maxLogLength)}... (truncated)';
  }
  return message;
}
```

### Debug Mode Detection

The Logger uses Flutter's `kDebugMode` constant to determine if the application is running in debug mode:

```dart
if (kDebugMode && _debugLogsEnabled) {
  print('DEBUG: [${_truncateMessage(tag)}] ${_truncateMessage(message)}');
}
```

## Best Practices

1. **Use Consistent Tags**: Use the class or component name as the tag for better organization
2. **Choose Appropriate Log Levels**:
   - `d`: Detailed information for debugging
   - `i`: General information about application flow
   - `w`: Potential issues that don't prevent operation
   - `e`: Errors that affect functionality
3. **Include Context**: Provide enough context in log messages to understand the situation
4. **Log Exceptions**: Always include the exception object when logging errors
5. **Don't Log Sensitive Data**: Avoid logging sensitive user information or credentials
6. **Be Concise**: Keep log messages clear and to the point

## Integration with Services

The Logger is used throughout the application's services for consistent logging:

### Example: RetryService

```dart
// Log retry attempt
Logger.d('RetryService', 'Retry attempt $attempts for $operationName failed, retrying in ${delay.inMilliseconds}ms: $e');

// Log successful completion
Logger.d('RetryService', 'Successfully completed $operationName after $attempts attempts');

// Log failure
Logger.e('RetryService', 'Failed to execute $operationName after $attempts attempts', e);
```

### Example: BatchService

```dart
// Log batch operation start
Logger.d('BatchService', 'Updating ${events.length} events in batch');

// Log batch commit
Logger.d('BatchService', 'Committed batch of ${batchEvents.length} events');

// Log batch error
Logger.e('BatchService', 'Error updating events in batch', e);
```

## Performance Considerations

- Logging is disabled in release builds to prevent performance impact
- Message truncation prevents memory issues with large log messages
- Debug logs can be selectively disabled for performance-sensitive sections

## Future Enhancements

Potential improvements to the Logger utility:

1. **File Logging**: Option to write logs to a file for later analysis
2. **Remote Logging**: Integration with remote logging services
3. **Log Filtering**: Runtime filtering of logs by tag or level
4. **Structured Logging**: Support for structured log formats (JSON)
5. **Log Rotation**: Automatic rotation of log files to manage storage
