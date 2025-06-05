import 'package:flutter_test/flutter_test.dart';
import 'package:yetuga/services/cache_manager.dart';
import 'package:yetuga/services/retry_service.dart';
import 'package:yetuga/services/prefetch_service.dart';
import 'package:yetuga/services/event_cache_service.dart';
import 'package:yetuga/services/firestore_config_service.dart';
import 'package:yetuga/utils/logger.dart';

void main() {
  test('Run simple service test', () async {
    final cacheManager = CacheManager();
    final eventCacheService = EventCacheService();
    final firestoreConfigService = FirestoreConfigService();
    final prefetchService = PrefetchService(cacheManager, eventCacheService, firestoreConfigService);
    final retryService = RetryService();

    Logger.d('ServiceTest', 'Running simple service test...');

    // Test CacheManager
    await cacheManager.put('test_key', 'test_value', priority: CacheManager.priorityHigh);
    final cachedValue = await cacheManager.get<String>('test_key');
    expect(cachedValue, 'test_value');

    // Test RetryService
    try {
      final result = await retryService.executeWithRetryAndFallback<String>(
        operation: () async {
          return 'success';
        },
        fallbackValue: 'fallback',
        maxRetries: 3,
        operationName: 'testOperation',
      );
      expect(result, 'success');
    } catch (e) {
      fail('RetryService test failed: $e');
    }

    // Test PrefetchService
    await prefetchService.trackEventView('test_event_id');
    await prefetchService.trackUserInteraction('test_user_id');
    final status = prefetchService.getPrefetchStatus();
    expect(status['trackedEvents'] > 0, true);

    Logger.d('ServiceTest', 'Service tests completed');
  });
}
