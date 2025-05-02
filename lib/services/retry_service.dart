import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// Provider for the RetryService
///
/// This provider makes the RetryService available throughout the application
/// via Riverpod's dependency injection system.
///
/// Usage:
/// ```dart
/// final retryService = ref.read(retryServiceProvider);
/// ```
final retryServiceProvider = Provider<RetryService>((ref) => RetryService());

/// A service that provides robust retry logic for asynchronous operations.
///
/// The RetryService implements industry-standard retry patterns including:
/// - Configurable retry attempts
/// - Exponential backoff
/// - Jitter to prevent thundering herd problems
/// - Timeout handling
/// - Selective retry based on exception type
/// - Batch operation support
///
/// This service is particularly useful for network operations, Firebase interactions,
/// and other potentially unreliable operations that may fail transiently.
class RetryService {
  /// Default maximum number of retry attempts
  static const int defaultMaxRetries = 3;

  /// Default initial delay before the first retry (500ms)
  static const Duration defaultInitialDelay = Duration(milliseconds: 500);

  /// Default multiplier for exponential backoff (each retry waits 1.5x longer)
  static const double defaultBackoffFactor = 1.5;

  /// Default maximum delay between retries (30 seconds)
  static const Duration defaultMaxDelay = Duration(seconds: 30);

  /// Default timeout for each operation attempt (15 seconds)
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Random number generator used to add jitter to retry delays
  /// to prevent multiple clients from retrying simultaneously
  final Random _random = Random();

  /// Executes an asynchronous operation with configurable retry logic.
  ///
  /// This method will attempt the provided [operation] and retry it if it fails,
  /// using exponential backoff with jitter between attempts. The operation will
  /// be retried up to [maxRetries] times or until it succeeds.
  ///
  /// Parameters:
  /// - [operation]: The asynchronous operation to execute
  /// - [maxRetries]: Maximum number of retry attempts (default: 3)
  /// - [initialDelay]: Initial delay before first retry (default: 500ms)
  /// - [backoffFactor]: Multiplier for exponential backoff (default: 1.5)
  /// - [maxDelay]: Maximum delay between retries (default: 30s)
  /// - [timeout]: Timeout for each operation attempt (default: 15s)
  /// - [shouldRetry]: Function to determine if an exception should trigger a retry
  /// - [operationName]: Name of the operation for logging purposes
  ///
  /// Returns:
  /// - The result of the operation if successful
  ///
  /// Throws:
  /// - The last exception encountered if all retry attempts fail
  Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = defaultMaxRetries,
    Duration initialDelay = defaultInitialDelay,
    double backoffFactor = defaultBackoffFactor,
    Duration maxDelay = defaultMaxDelay,
    Duration timeout = defaultTimeout,
    bool Function(Exception)? shouldRetry,
    String operationName = 'operation',
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      attempts++;

      try {
        // Execute the operation with timeout
        final result = await operation().timeout(timeout);

        // If successful, return the result
        if (attempts > 1) {
          Logger.d('RetryService', 'Successfully completed $operationName after $attempts attempts');
        }

        return result;
      } catch (e) {
        final isException = e is Exception;
        final shouldRetryException = isException && (shouldRetry == null || shouldRetry(e));

        // Check if we should retry
        if (attempts >= maxRetries || !shouldRetryException) {
          Logger.e('RetryService', 'Failed to execute $operationName after $attempts attempts', e);
          rethrow;
        }

        // Calculate delay with jitter
        final jitter = _random.nextDouble() * 0.3 + 0.85; // 0.85-1.15 jitter factor
        final nextDelayMs = (delay.inMilliseconds * backoffFactor * jitter).round();
        delay = Duration(milliseconds: min(nextDelayMs, maxDelay.inMilliseconds));

        Logger.d('RetryService', 'Retry attempt $attempts for $operationName failed, retrying in ${delay.inMilliseconds}ms: $e');

        // Wait before retrying
        await Future.delayed(delay);
      }
    }
  }

  /// Executes an asynchronous operation with retry logic and returns a fallback value if all retries fail.
  ///
  /// This method works like [executeWithRetry] but instead of throwing an exception
  /// when all retries fail, it returns the provided [fallbackValue]. This is useful
  /// for non-critical operations where a default or cached value can be used as a fallback.
  ///
  /// Parameters:
  /// - [operation]: The asynchronous operation to execute
  /// - [fallbackValue]: Value to return if all retry attempts fail
  /// - [maxRetries]: Maximum number of retry attempts (default: 3)
  /// - [initialDelay]: Initial delay before first retry (default: 500ms)
  /// - [backoffFactor]: Multiplier for exponential backoff (default: 1.5)
  /// - [maxDelay]: Maximum delay between retries (default: 30s)
  /// - [timeout]: Timeout for each operation attempt (default: 15s)
  /// - [shouldRetry]: Function to determine if an exception should trigger a retry
  /// - [operationName]: Name of the operation for logging purposes
  ///
  /// Returns:
  /// - The result of the operation if successful, or the fallback value if all retries fail
  Future<T> executeWithRetryAndFallback<T>({
    required Future<T> Function() operation,
    required T fallbackValue,
    int maxRetries = defaultMaxRetries,
    Duration initialDelay = defaultInitialDelay,
    double backoffFactor = defaultBackoffFactor,
    Duration maxDelay = defaultMaxDelay,
    Duration timeout = defaultTimeout,
    bool Function(Exception)? shouldRetry,
    String operationName = 'operation',
  }) async {
    try {
      return await executeWithRetry(
        operation: operation,
        maxRetries: maxRetries,
        initialDelay: initialDelay,
        backoffFactor: backoffFactor,
        maxDelay: maxDelay,
        timeout: timeout,
        shouldRetry: shouldRetry,
        operationName: operationName,
      );
    } catch (e) {
      Logger.e('RetryService', 'All retries failed for $operationName, using fallback value', e);
      return fallbackValue;
    }
  }

  /// Determines if an exception is a common network error that should be retried.
  ///
  /// This method checks if the exception message contains common network error keywords
  /// such as 'timeout', 'connection', 'network', etc.
  ///
  /// Parameters:
  /// - [e]: The exception to check
  ///
  /// Returns:
  /// - `true` if the exception is a network error that should be retried, `false` otherwise
  bool isNetworkError(Exception e) {
    final errorMessage = e.toString().toLowerCase();
    return errorMessage.contains('timeout') ||
           errorMessage.contains('connection') ||
           errorMessage.contains('network') ||
           errorMessage.contains('socket') ||
           errorMessage.contains('host') ||
           errorMessage.contains('connection refused') ||
           errorMessage.contains('unreachable');
  }

  /// Determines if an exception is a Firestore error that should be retried.
  ///
  /// This method checks if the exception is a network error or contains Firestore-specific
  /// error keywords that indicate the operation can be safely retried, such as 'unavailable',
  /// 'deadline-exceeded', 'resource-exhausted', etc.
  ///
  /// Parameters:
  /// - [e]: The exception to check
  ///
  /// Returns:
  /// - `true` if the exception is a Firestore error that should be retried, `false` otherwise
  bool isFirestoreRetryableError(Exception e) {
    final errorMessage = e.toString().toLowerCase();
    return isNetworkError(e) ||
           errorMessage.contains('unavailable') ||
           errorMessage.contains('deadline-exceeded') ||
           errorMessage.contains('resource-exhausted') ||
           errorMessage.contains('internal') ||
           errorMessage.contains('service unavailable');
  }

  /// Executes multiple asynchronous operations with retry logic, retrying only the failed operations.
  ///
  /// This method attempts all operations once, then retries only the failed operations
  /// with exponential backoff. This is more efficient than retrying all operations
  /// when only some have failed.
  ///
  /// Parameters:
  /// - [operations]: List of asynchronous operations to execute
  /// - [maxRetries]: Maximum number of retry attempts (default: 3)
  /// - [initialDelay]: Initial delay before first retry (default: 500ms)
  /// - [backoffFactor]: Multiplier for exponential backoff (default: 1.5)
  /// - [maxDelay]: Maximum delay between retries (default: 30s)
  /// - [timeout]: Timeout for each operation attempt (default: 15s)
  /// - [shouldRetry]: Function to determine if an exception should trigger a retry
  /// - [operationName]: Name of the operation for logging purposes
  ///
  /// Returns:
  /// - A list containing the results of each operation. The list will have the same length as the input operations list.
  ///
  /// Throws:
  /// - Exception if any operations still fail after all retry attempts
  Future<List<dynamic>> executeBatchWithRetry<T>({
    required List<Future<T> Function()> operations,
    int maxRetries = defaultMaxRetries,
    Duration initialDelay = defaultInitialDelay,
    double backoffFactor = defaultBackoffFactor,
    Duration maxDelay = defaultMaxDelay,
    Duration timeout = defaultTimeout,
    bool Function(Exception)? shouldRetry,
    String operationName = 'batch operation',
  }) async {
    final results = <dynamic>[];
    final failedOperations = <int>[];

    // First attempt for all operations
    for (int i = 0; i < operations.length; i++) {
      try {
        final result = await operations[i]().timeout(timeout);
        results.add(result);
      } catch (e) {
        Logger.d('RetryService', 'Operation $i in batch failed, will retry: $e');
        // Create a placeholder in the results list
        // We'll use a dummy object that will be replaced later
        results.add(Object());
        failedOperations.add(i);
      }
    }

    // Retry failed operations with backoff
    if (failedOperations.isNotEmpty) {
      int retryAttempt = 1;
      Duration delay = initialDelay;

      while (retryAttempt < maxRetries && failedOperations.isNotEmpty) {
        // Wait before retrying
        await Future.delayed(delay);

        // Calculate next delay with jitter
        final jitter = _random.nextDouble() * 0.3 + 0.85; // 0.85-1.15 jitter factor
        final nextDelayMs = (delay.inMilliseconds * backoffFactor * jitter).round();
        delay = Duration(milliseconds: min(nextDelayMs, maxDelay.inMilliseconds));

        Logger.d('RetryService', 'Retry attempt $retryAttempt for ${failedOperations.length} operations in batch');

        // Try to execute failed operations
        final stillFailedOperations = <int>[];

        for (final index in failedOperations) {
          try {
            final result = await operations[index]().timeout(timeout);
            results[index] = result;
          } catch (e) {
            Logger.d('RetryService', 'Operation $index in batch still failed on retry attempt $retryAttempt: $e');
            stillFailedOperations.add(index);
          }
        }

        failedOperations.clear();
        failedOperations.addAll(stillFailedOperations);
        retryAttempt++;
      }

      if (failedOperations.isNotEmpty) {
        Logger.e('RetryService', 'Failed to execute ${failedOperations.length} operations in batch after $maxRetries attempts');
        throw Exception('Failed to execute ${failedOperations.length} operations in batch after $maxRetries attempts');
      }
    }

    // Return the results, which may contain placeholder objects for operations that failed
    return results;
  }
}
