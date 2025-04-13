import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../models/onboarding_data.dart';

// Provider for the StorageService instance
final storageServiceProvider = Provider<StorageService>((ref) {
  final service = StorageService();
  // Initialize the service
  service.init();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for saving onboarding data to Hive
final saveOnboardingDataProvider = FutureProvider.family<void, OnboardingData>((ref, data) async {
  final storageService = ref.read(storageServiceProvider);
  await storageService.saveOnboardingData(data);
});

// Provider for getting onboarding data from Hive
final getOnboardingDataProvider = FutureProvider<OnboardingData?>((ref) async {
  final storageService = ref.read(storageServiceProvider);
  return await storageService.getOnboardingData();
});

// Provider for clearing onboarding data from Hive
final clearOnboardingDataProvider = FutureProvider<void>((ref) async {
  final storageService = ref.read(storageServiceProvider);
  await storageService.clearOnboardingData();
});
