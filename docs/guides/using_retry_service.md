# Guide: Using the RetryService

This guide provides practical examples and best practices for using the RetryService in the Yetu'ga application.

## Table of Contents

1. [Basic Integration](#basic-integration)
2. [Common Use Cases](#common-use-cases)
3. [Advanced Patterns](#advanced-patterns)
4. [Testing and Debugging](#testing-and-debugging)
5. [Performance Considerations](#performance-considerations)

## Basic Integration

### Step 1: Access the RetryService

The RetryService is available through a Riverpod provider:

```dart
final retryService = ref.read(retryServiceProvider);
```

### Step 2: Wrap Operations with Retry Logic

```dart
Future<UserData> fetchUserData(String userId) async {
  return await retryService.executeWithRetry<UserData>(
    operation: () async {
      final doc = await firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }
      return UserData.fromMap(doc.data()!);
    },
    maxRetries: 3,
    operationName: 'fetchUserData',
  );
}
```

### Step 3: Add Fallback for Non-Critical Operations

```dart
Future<List<Event>> fetchRecommendedEvents() async {
  return await retryService.executeWithRetryAndFallback<List<Event>>(
    operation: () async {
      final snapshot = await firestore.collection('events')
          .where('isRecommended', isEqualTo: true)
          .limit(10)
          .get();
      return snapshot.docs.map((doc) => Event.fromMap(doc.data())).toList();
    },
    fallbackValue: [], // Return empty list if operation fails
    operationName: 'fetchRecommendedEvents',
  );
}
```

## Common Use Cases

### Firebase Operations

```dart
// Firestore read operation
Future<DocumentSnapshot> getDocument(String collection, String docId) async {
  return await retryService.executeWithRetry<DocumentSnapshot>(
    operation: () async {
      return await firestore.collection(collection).doc(docId).get();
    },
    shouldRetry: retryService.isFirestoreRetryableError,
    operationName: 'getDocument($collection/$docId)',
  );
}

// Firestore write operation
Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
  await retryService.executeWithRetry<void>(
    operation: () async {
      await firestore.collection(collection).doc(docId).update(data);
    },
    shouldRetry: retryService.isFirestoreRetryableError,
    operationName: 'updateDocument($collection/$docId)',
  );
}

// Firebase Storage operation
Future<String> uploadImage(File file, String path) async {
  return await retryService.executeWithRetry<String>(
    operation: () async {
      final ref = storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    },
    maxRetries: 5, // More retries for file uploads
    initialDelay: const Duration(seconds: 1),
    operationName: 'uploadImage($path)',
  );
}
```

### Network Operations

```dart
// API request
Future<ApiResponse> fetchApiData(String endpoint) async {
  return await retryService.executeWithRetry<ApiResponse>(
    operation: () async {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode != 200) {
        throw Exception('API error: ${response.statusCode}');
      }
      return ApiResponse.fromJson(jsonDecode(response.body));
    },
    shouldRetry: (e) => retryService.isNetworkError(e) || _isServerError(e),
    operationName: 'fetchApiData($endpoint)',
  );
}

// Custom server error detection
bool _isServerError(Exception e) {
  final message = e.toString().toLowerCase();
  return message.contains('500') || 
         message.contains('503') || 
         message.contains('server error');
}
```

### Batch Operations

```dart
// Process multiple user updates
Future<void> updateUserStatuses(Map<String, String> userStatuses) async {
  final operations = userStatuses.entries.map((entry) {
    return () async {
      await firestore.collection('users').doc(entry.key).update({
        'status': entry.value,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return entry.key;
    };
  }).toList();

  await retryService.executeBatchWithRetry<String>(
    operations: operations,
    maxRetries: 3,
    shouldRetry: retryService.isFirestoreRetryableError,
    operationName: 'updateUserStatuses',
  );
}
```

## Advanced Patterns

### Combining with Other Services

```dart
class EventService {
  final RetryService _retryService;
  final BatchService _batchService;
  
  EventService(this._retryService, this._batchService);
  
  // Combine RetryService with BatchService
  Future<void> updateEventsWithRetry(List<EventModel> events) async {
    await _retryService.executeWithRetry<void>(
      operation: () async {
        await _batchService.updateEvents(events);
      },
      shouldRetry: _retryService.isFirestoreRetryableError,
      operationName: 'batchUpdateEvents',
    );
  }
}
```

### Custom Retry Predicates

```dart
// Custom retry predicate for API errors
bool shouldRetryApiCall(Exception e) {
  final message = e.toString().toLowerCase();
  
  // Don't retry client errors (4xx)
  if (message.contains('400') || 
      message.contains('401') || 
      message.contains('403') || 
      message.contains('404')) {
    return false;
  }
  
  // Retry server errors (5xx)
  if (message.contains('500') || 
      message.contains('502') || 
      message.contains('503') || 
      message.contains('504')) {
    return true;
  }
  
  // Retry network errors
  return message.contains('timeout') || 
         message.contains('connection') || 
         message.contains('network');
}

// Using the custom predicate
Future<ApiResponse> fetchData() async {
  return await retryService.executeWithRetry<ApiResponse>(
    operation: () async {
      // API call implementation
    },
    shouldRetry: shouldRetryApiCall,
    operationName: 'fetchApiData',
  );
}
```

### Progressive Retry Strategy

```dart
// Different retry strategies based on operation type
Future<T> executeWithProgressiveRetry<T>({
  required Future<T> Function() operation,
  required String operationType,
  required String operationId,
}) async {
  // Configure retry strategy based on operation type
  int maxRetries;
  Duration initialDelay;
  double backoffFactor;
  
  switch (operationType) {
    case 'read':
      maxRetries = 5;
      initialDelay = const Duration(milliseconds: 200);
      backoffFactor = 1.5;
      break;
    case 'write':
      maxRetries = 3;
      initialDelay = const Duration(milliseconds: 500);
      backoffFactor = 2.0;
      break;
    case 'upload':
      maxRetries = 10;
      initialDelay = const Duration(seconds: 1);
      backoffFactor = 1.3;
      break;
    default:
      maxRetries = 3;
      initialDelay = const Duration(milliseconds: 500);
      backoffFactor = 1.5;
  }
  
  return await retryService.executeWithRetry<T>(
    operation: operation,
    maxRetries: maxRetries,
    initialDelay: initialDelay,
    backoffFactor: backoffFactor,
    shouldRetry: retryService.isFirestoreRetryableError,
    operationName: '$operationType:$operationId',
  );
}
```

## Testing and Debugging

### Using the RetryTestScreen

The application includes a `RetryTestScreen` for testing retry functionality:

1. Navigate to the test menu and select "Retry Test"
2. Configure the success rate, delay, and max retries
3. Test different retry scenarios:
   - Single retry
   - Retry with fallback
   - Batch retry

### Debugging Retry Issues

1. **Enable Detailed Logging**:
   ```dart
   Logger.setDebugLogsEnabled(true);
   ```

2. **Monitor Retry Patterns**:
   - Look for operations that frequently require retries
   - Check for patterns in error messages
   - Identify operations with high failure rates

3. **Common Issues and Solutions**:

   | Issue | Possible Causes | Solutions |
   |-------|----------------|-----------|
   | Excessive retries | Network instability, server issues | Increase backoff factor, check connectivity |
   | Timeout errors | Operation too slow, server overloaded | Increase timeout duration, optimize operation |
   | Non-retryable errors | Client errors, invalid data | Improve validation, fix client-side issues |
   | Batch operation failures | Too many operations, partial failures | Reduce batch size, improve error handling |

## Performance Considerations

### Optimizing Retry Parameters

- **Max Retries**: Balance between reliability and user experience
  - Critical operations: 5-10 retries
  - Non-critical operations: 2-3 retries

- **Initial Delay**: Start with a reasonable delay based on operation type
  - Quick operations (reads): 200-500ms
  - Slower operations (writes): 500-1000ms
  - File uploads: 1-2 seconds

- **Backoff Factor**: Prevent overwhelming the server
  - Standard: 1.5-2.0
  - High-volume operations: 2.0-3.0

- **Max Delay**: Cap the maximum delay to prevent excessive waiting
  - Standard: 30 seconds
  - Background operations: 60-120 seconds

### Balancing Retry Logic

- **User-Facing Operations**:
  - Use shorter timeouts and fewer retries
  - Provide feedback during retries
  - Consider fallback values for better UX

- **Background Operations**:
  - Use longer timeouts and more retries
  - Implement more aggressive backoff
  - Log detailed information for debugging

### Example: Optimized Retry Configuration

```dart
// User-facing operation (e.g., loading profile)
Future<UserProfile> loadUserProfile(String userId) async {
  return await retryService.executeWithRetryAndFallback<UserProfile>(
    operation: () async {
      // Implementation
    },
    fallbackValue: UserProfile.empty(), // Show placeholder data
    maxRetries: 2, // Limited retries for UI operations
    initialDelay: const Duration(milliseconds: 300),
    timeout: const Duration(seconds: 5), // Short timeout
    operationName: 'loadUserProfile',
  );
}

// Background operation (e.g., syncing data)
Future<void> syncUserData(String userId) async {
  return await retryService.executeWithRetry<void>(
    operation: () async {
      // Implementation
    },
    maxRetries: 10, // More retries for background operations
    initialDelay: const Duration(seconds: 1),
    backoffFactor: 2.0, // More aggressive backoff
    timeout: const Duration(seconds: 30), // Longer timeout
    operationName: 'syncUserData',
  );
}
```

## Conclusion

The RetryService provides a robust foundation for handling network operations in the Yetu'ga application. By following these guidelines and examples, you can ensure reliable data operations even in challenging network conditions.

Remember that retry logic is not a substitute for addressing underlying issues. Monitor retry patterns and fix recurring problems at their source whenever possible.
