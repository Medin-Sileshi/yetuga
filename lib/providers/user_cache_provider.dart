import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_cache_service.dart';

// Provider for the UserCacheService instance
final userCacheServiceProvider = Provider<UserCacheService>((ref) {
  final service = UserCacheService();
  // Initialize the service
  service.init();
  return service;
});
