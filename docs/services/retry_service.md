# RetryService Documentation

## Overview

The `RetryService` is a robust utility for handling network operations with retry logic in the Yetu'ga application. It provides mechanisms to execute operations with configurable retry policies, including exponential backoff with jitter, timeout handling, and batch operation support.

## Features

- **Configurable Retry Policies**: Customize max retries, delays, backoff factors, and timeouts
- **Exponential Backoff**: Implements industry-standard exponential backoff algorithm
- **Jitter**: Adds randomized jitter to prevent thundering herd problems
- **Fallback Support**: Graceful degradation with fallback values
- **Batch Operations**: Support for retrying multiple operations in parallel
- **Selective Retry**: Configurable predicates to determine which errors should trigger retries
- **Timeout Handling**: Automatic timeout for operations that take too long
- **Comprehensive Logging**: Detailed logging of retry attempts and outcomes

## Usage

### Basic Usage

```dart
final result = await retryService.executeWithRetry<String>(
  operation: () async {
    // Your async operation here
    return await apiClient.fetchData();
  },
  maxRetries: 3,
  operationName: 'fetchUserData',
);
```

### With Fallback

```dart
final result = await retryService.executeWithRetryAndFallback<List<Event>>(
  operation: () async {
    return await eventService.getEvents();
  },
  fallbackValue: [], // Return empty list if all retries fail
  maxRetries: 5,
  operationName: 'fetchEvents',
);
```

### Batch Operations

```dart
final operations = [
  () async => await userService.fetchUser(userId1),
  () async => await userService.fetchUser(userId2),
  () async => await userService.fetchUser(userId3),
];

final results = await retryService.executeBatchWithRetry<User>(
  operations: operations,
  maxRetries: 3,
  operationName: 'fetchMultipleUsers',
);
```

### Custom Retry Predicates

```dart
final result = await retryService.executeWithRetry<DocumentSnapshot>(
  operation: () async {
    return await firestore.collection('users').doc(userId).get();
  },
  shouldRetry: (e) => retryService.isFirestoreRetryableError(e),
  operationName: 'fetchUserDocument',
);
```

## Configuration Options

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxRetries` | `int` | 3 | Maximum number of retry attempts |
| `initialDelay` | `Duration` | 500ms | Initial delay before first retry |
| `backoffFactor` | `double` | 1.5 | Multiplier for exponential backoff |
| `maxDelay` | `Duration` | 30s | Maximum delay between retries |
| `timeout` | `Duration` | 15s | Timeout for each operation attempt |
| `shouldRetry` | `Function` | null | Predicate to determine if an error should trigger retry |
| `operationName` | `String` | 'operation' | Name for logging purposes |

## Retry Predicates

The service includes built-in predicates for common error types:

### Network Errors

```dart
bool isNetworkError(Exception e)
```

Detects common network-related errors like timeouts, connection issues, etc.

### Firestore Errors

```dart
bool isFirestoreRetryableError(Exception e)
```

Detects Firestore-specific errors that are safe to retry, including:
- Network errors
- "Unavailable" errors
- "Deadline exceeded" errors
- "Resource exhausted" errors
- Internal server errors

## Implementation Details

### Exponential Backoff with Jitter

The service implements exponential backoff with jitter to prevent the "thundering herd" problem:

```dart
final jitter = _random.nextDouble() * 0.3 + 0.85; // 0.85-1.15 jitter factor
final nextDelayMs = (delay.inMilliseconds * backoffFactor * jitter).round();
delay = Duration(milliseconds: min(nextDelayMs, maxDelay.inMilliseconds));
```

### Batch Operation Handling

For batch operations, the service:
1. Attempts all operations once
2. Tracks which operations failed
3. Retries only the failed operations with exponential backoff
4. Continues until all operations succeed or max retries is reached

## Best Practices

1. **Use Descriptive Operation Names**: Provide meaningful operation names for better logging and debugging
2. **Set Appropriate Timeouts**: Configure timeouts based on expected operation duration
3. **Use Custom Retry Predicates**: Implement custom predicates for specific error types
4. **Consider Fallbacks**: Use fallback values for non-critical operations
5. **Batch Related Operations**: Group related operations using batch functionality
6. **Monitor Retry Patterns**: Use logs to identify frequently retried operations and fix underlying issues

## Integration with Other Services

The RetryService is designed to work with other services in the application:

- **FirebaseService**: Use with Firestore operations
- **EventService**: Fetch and update events with retry support
- **ChatService**: Ensure message delivery with retries
- **SyncService**: Synchronize local and remote data reliably

## Example: Integration with Firebase

```dart
class FirebaseService {
  final RetryService _retryService;
  
  FirebaseService(this._retryService);
  
  Future<DocumentSnapshot> getDocument(String collection, String docId) async {
    return await _retryService.executeWithRetry<DocumentSnapshot>(
      operation: () async {
        return await FirebaseFirestore.instance
            .collection(collection)
            .doc(docId)
            .get();
      },
      shouldRetry: _retryService.isFirestoreRetryableError,
      operationName: 'getDocument($collection/$docId)',
    );
  }
}
```
