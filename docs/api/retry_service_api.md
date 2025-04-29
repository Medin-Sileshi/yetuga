# RetryService API Reference

## Class: RetryService

A service that provides robust retry logic for asynchronous operations, particularly network and Firebase operations.

### Constants

| Name | Type | Value | Description |
|------|------|-------|-------------|
| `DEFAULT_MAX_RETRIES` | `int` | `3` | Default maximum number of retry attempts |
| `DEFAULT_INITIAL_DELAY` | `Duration` | `Duration(milliseconds: 500)` | Default initial delay before first retry |
| `DEFAULT_BACKOFF_FACTOR` | `double` | `1.5` | Default multiplier for exponential backoff |
| `DEFAULT_MAX_DELAY` | `Duration` | `Duration(seconds: 30)` | Default maximum delay between retries |
| `DEFAULT_TIMEOUT` | `Duration` | `Duration(seconds: 15)` | Default timeout for each operation attempt |

### Properties

| Name | Type | Description |
|------|------|-------------|
| `_random` | `Random` | Random number generator for jitter calculation |

### Methods

#### executeWithRetry\<T>

Executes an asynchronous operation with retry logic.

```dart
Future<T> executeWithRetry<T>({
  required Future<T> Function() operation,
  int maxRetries = DEFAULT_MAX_RETRIES,
  Duration initialDelay = DEFAULT_INITIAL_DELAY,
  double backoffFactor = DEFAULT_BACKOFF_FACTOR,
  Duration maxDelay = DEFAULT_MAX_DELAY,
  Duration timeout = DEFAULT_TIMEOUT,
  bool Function(Exception)? shouldRetry,
  String operationName = 'operation',
})
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `operation` | `Future<T> Function()` | required | The asynchronous operation to execute |
| `maxRetries` | `int` | `DEFAULT_MAX_RETRIES` | Maximum number of retry attempts |
| `initialDelay` | `Duration` | `DEFAULT_INITIAL_DELAY` | Initial delay before first retry |
| `backoffFactor` | `double` | `DEFAULT_BACKOFF_FACTOR` | Multiplier for exponential backoff |
| `maxDelay` | `Duration` | `DEFAULT_MAX_DELAY` | Maximum delay between retries |
| `timeout` | `Duration` | `DEFAULT_TIMEOUT` | Timeout for each operation attempt |
| `shouldRetry` | `bool Function(Exception)?` | `null` | Function to determine if an exception should trigger a retry |
| `operationName` | `String` | `'operation'` | Name of the operation for logging purposes |

**Returns:**

`Future<T>`: The result of the operation if successful.

**Throws:**

The last exception encountered if all retry attempts fail.

**Example:**

```dart
final document = await retryService.executeWithRetry<DocumentSnapshot>(
  operation: () async {
    return await firestore.collection('users').doc(userId).get();
  },
  maxRetries: 5,
  shouldRetry: retryService.isFirestoreRetryableError,
  operationName: 'fetchUserDocument',
);
```

#### executeWithRetryAndFallback\<T>

Executes an asynchronous operation with retry logic and returns a fallback value if all retries fail.

```dart
Future<T> executeWithRetryAndFallback<T>({
  required Future<T> Function() operation,
  required T fallbackValue,
  int maxRetries = DEFAULT_MAX_RETRIES,
  Duration initialDelay = DEFAULT_INITIAL_DELAY,
  double backoffFactor = DEFAULT_BACKOFF_FACTOR,
  Duration maxDelay = DEFAULT_MAX_DELAY,
  Duration timeout = DEFAULT_TIMEOUT,
  bool Function(Exception)? shouldRetry,
  String operationName = 'operation',
})
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `operation` | `Future<T> Function()` | required | The asynchronous operation to execute |
| `fallbackValue` | `T` | required | Value to return if all retry attempts fail |
| `maxRetries` | `int` | `DEFAULT_MAX_RETRIES` | Maximum number of retry attempts |
| `initialDelay` | `Duration` | `DEFAULT_INITIAL_DELAY` | Initial delay before first retry |
| `backoffFactor` | `double` | `DEFAULT_BACKOFF_FACTOR` | Multiplier for exponential backoff |
| `maxDelay` | `Duration` | `DEFAULT_MAX_DELAY` | Maximum delay between retries |
| `timeout` | `Duration` | `DEFAULT_TIMEOUT` | Timeout for each operation attempt |
| `shouldRetry` | `bool Function(Exception)?` | `null` | Function to determine if an exception should trigger a retry |
| `operationName` | `String` | `'operation'` | Name of the operation for logging purposes |

**Returns:**

`Future<T>`: The result of the operation if successful, or the fallback value if all retries fail.

**Example:**

```dart
final events = await retryService.executeWithRetryAndFallback<List<Event>>(
  operation: () async {
    final snapshot = await firestore.collection('events').get();
    return snapshot.docs.map((doc) => Event.fromMap(doc.data())).toList();
  },
  fallbackValue: [], // Return empty list if all retries fail
  maxRetries: 3,
  operationName: 'fetchEvents',
);
```

#### executeBatchWithRetry\<T>

Executes multiple asynchronous operations with retry logic, retrying only the failed operations.

```dart
Future<List<dynamic>> executeBatchWithRetry<T>({
  required List<Future<T> Function()> operations,
  int maxRetries = DEFAULT_MAX_RETRIES,
  Duration initialDelay = DEFAULT_INITIAL_DELAY,
  double backoffFactor = DEFAULT_BACKOFF_FACTOR,
  Duration maxDelay = DEFAULT_MAX_DELAY,
  Duration timeout = DEFAULT_TIMEOUT,
  bool Function(Exception)? shouldRetry,
  String operationName = 'batch operation',
})
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `operations` | `List<Future<T> Function()>` | required | List of asynchronous operations to execute |
| `maxRetries` | `int` | `DEFAULT_MAX_RETRIES` | Maximum number of retry attempts |
| `initialDelay` | `Duration` | `DEFAULT_INITIAL_DELAY` | Initial delay before first retry |
| `backoffFactor` | `double` | `DEFAULT_BACKOFF_FACTOR` | Multiplier for exponential backoff |
| `maxDelay` | `Duration` | `DEFAULT_MAX_DELAY` | Maximum delay between retries |
| `timeout` | `Duration` | `DEFAULT_TIMEOUT` | Timeout for each operation attempt |
| `shouldRetry` | `bool Function(Exception)?` | `null` | Function to determine if an exception should trigger a retry |
| `operationName` | `String` | `'batch operation'` | Name of the operation for logging purposes |

**Returns:**

`Future<List<dynamic>>`: A list containing the results of each operation. The list will have the same length as the input operations list.

**Throws:**

`Exception`: If any operations still fail after all retry attempts.

**Example:**

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

#### isNetworkError

Determines if an exception is a common network error that should be retried.

```dart
bool isNetworkError(Exception e)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `e` | `Exception` | The exception to check |

**Returns:**

`bool`: `true` if the exception is a network error that should be retried, `false` otherwise.

**Example:**

```dart
if (retryService.isNetworkError(exception)) {
  // Handle network error
}
```

#### isFirestoreRetryableError

Determines if an exception is a Firestore error that should be retried.

```dart
bool isFirestoreRetryableError(Exception e)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `e` | `Exception` | The exception to check |

**Returns:**

`bool`: `true` if the exception is a Firestore error that should be retried, `false` otherwise.

**Example:**

```dart
final result = await retryService.executeWithRetry<DocumentSnapshot>(
  operation: () async {
    return await firestore.collection('users').doc(userId).get();
  },
  shouldRetry: retryService.isFirestoreRetryableError,
  operationName: 'fetchUserDocument',
);
```

## Provider: retryServiceProvider

A Riverpod provider for the RetryService.

```dart
final retryServiceProvider = Provider<RetryService>((ref) => RetryService());
```

**Usage:**

```dart
final retryService = ref.read(retryServiceProvider);
```

## Implementation Details

### Exponential Backoff with Jitter

The service implements exponential backoff with jitter to prevent the "thundering herd" problem:

```dart
final jitter = _random.nextDouble() * 0.3 + 0.85; // 0.85-1.15 jitter factor
final nextDelayMs = (delay.inMilliseconds * backoffFactor * jitter).round();
delay = Duration(milliseconds: min(nextDelayMs, maxDelay.inMilliseconds));
```

### Retry Logic

The core retry logic is implemented in the `executeWithRetry` method:

1. Attempt the operation
2. If successful, return the result
3. If failed and retries remain:
   - Calculate next delay with exponential backoff and jitter
   - Log the failure and retry attempt
   - Wait for the calculated delay
   - Retry the operation
4. If all retries fail, throw the last exception

### Batch Operation Handling

For batch operations, the service:

1. Attempts all operations once
2. Tracks which operations failed
3. Retries only the failed operations with exponential backoff
4. Continues until all operations succeed or max retries is reached

## Error Handling

The RetryService handles errors in a structured way:

1. For single operations:
   - If the operation succeeds, return the result
   - If the operation fails and should be retried, log and retry
   - If the operation fails and should not be retried, rethrow the exception
   - If all retries fail, rethrow the last exception

2. For operations with fallback:
   - If the operation succeeds, return the result
   - If all retries fail, log the failure and return the fallback value

3. For batch operations:
   - If all operations succeed, return the results
   - If some operations fail, retry only the failed operations
   - If any operations still fail after all retries, throw an exception

## Logging

The RetryService uses the Logger utility for comprehensive logging:

- Debug logs for retry attempts and successful completions
- Error logs for failed operations after all retries
- Includes operation name, attempt number, and delay information

## Thread Safety

The RetryService is designed to be thread-safe:

- No shared mutable state between operations
- Each operation maintains its own retry state
- Random number generator is used in a thread-safe manner
