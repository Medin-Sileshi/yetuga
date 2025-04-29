import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/event_service.dart';
import '../services/user_search_service.dart';
import '../services/batch_service.dart';
import '../services/event_cache_service.dart';
import '../services/retry_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/rsvp_service.dart';

// Push Notification Service Provider
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

// Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final pushNotificationService = ref.watch(pushNotificationServiceProvider);
  return NotificationService(pushNotificationService);
});

// Event Service Provider
final eventServiceProvider = Provider<EventService>((ref) {
  final eventCacheService = ref.watch(eventCacheServiceProvider);
  final batchService = ref.watch(batchServiceProvider);
  final retryService = ref.watch(retryServiceProvider);
  final pushNotificationService = ref.watch(pushNotificationServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  // We still pass these services to maintain the constructor signature, but they're not used as fields anymore
  return EventService(eventCacheService, batchService, retryService, pushNotificationService, notificationService);
});

// User Search Service Provider
final userSearchServiceProvider = Provider<UserSearchService>((ref) {
  return UserSearchService();
});

// Event Cache Service Provider
final eventCacheServiceProvider = Provider<EventCacheService>((ref) {
  return EventCacheService();
});

// Batch Service Provider
final batchServiceProvider = Provider<BatchService>((ref) {
  return BatchService();
});

// Retry Service Provider
final retryServiceProvider = Provider<RetryService>((ref) {
  return RetryService();
});

// RSVP Service Provider
final rsvpServiceProvider = Provider<RSVPService>((ref) {
  final pushNotificationService = ref.watch(pushNotificationServiceProvider);
  return RSVPService(pushNotificationService);
});
