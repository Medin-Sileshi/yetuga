import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'firebase_options.dart';
import 'models/onboarding_data.dart';
import 'models/onboarding_cache.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/authenticated_home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/theme_provider.dart';
import 'services/firestore_config_service.dart';
import 'services/sync_service.dart';
import 'services/user_cache_service.dart';
import 'services/push_notification_service.dart';
import 'services/cache_manager.dart';
import 'services/prefetch_service.dart';
import 'services/retry_service.dart';
import 'services/global_navigation_service.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';
import 'services/firebase_service.dart';
import 'services/hive_service.dart';
import 'services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Disable debug logs in production to prevent memory issues
  // Only enable in development
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  Logger.setDebugLogsEnabled(!isProduction);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firestore with persistence
  final firestoreConfigService = FirestoreConfigService();
  await firestoreConfigService.initializeFirestore();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(OnboardingDataAdapter());
  Hive.registerAdapter(OnboardingCacheAdapter());

  // Clear Hive boxes to force a fresh sync with Firebase
  try {
    Logger.d('Main', 'Clearing Hive boxes to force a fresh sync with Firebase');
    await Hive.deleteBoxFromDisk('onboarding');
    await Hive.deleteBoxFromDisk('onboarding_cache');
  } catch (e) {
    Logger.d('Main', 'Error clearing Hive boxes: $e');
  }

  // Open the boxes
  try {
    await Hive.openBox<OnboardingData>('onboarding');
    await Hive.openBox<OnboardingCache>('onboarding_cache');
    await Hive.openBox('user_cache'); // Open the user cache box
    Logger.d('Main', 'Hive boxes opened successfully');

    // Initialize the user cache service
    await userCacheService.init();
    Logger.d('Main', 'User cache service initialized');

    // Initialize push notification service
    final pushNotificationService = PushNotificationService();
    await pushNotificationService.initialize();
    Logger.d('Main', 'Push notification service initialized');

    // Initialize the cache manager
    final container = ProviderContainer();
    final cacheManager = container.read(cacheManagerProvider);
    await cacheManager.initialize();
    Logger.d('Main', 'Cache manager initialized');

    // Initialize the retry service
    final retryService = container.read(retryServiceProvider);
    Logger.d('Main', 'Retry service initialized');

    // Initialize the sync service
    final syncService = container.read(syncServiceProvider);
    await syncService.initialize();
    Logger.d('Main', 'Sync service initialized');

    // Initialize the prefetch service
    final prefetchService = container.read(prefetchServiceProvider);
    await prefetchService.initialize();
    Logger.d('Main', 'Prefetch service initialized');

    // Run a simple test to verify services are working
    _runSimpleServiceTest(cacheManager, retryService, prefetchService);
  } catch (e) {
    Logger.d('Main', 'Error opening Hive boxes or initializing cache service: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

// Simple test function to verify that our services are working
Future<void> _runSimpleServiceTest(
    CacheManager cacheManager,
    RetryService retryService,
    PrefetchService prefetchService) async {
  try {
    Logger.d('ServiceTest', 'Running simple service test...');

    // Test CacheManager
    await cacheManager.put('test_key', 'test_value', priority: CacheManager.priorityHigh);
    final cachedValue = await cacheManager.get<String>('test_key');
    Logger.d('ServiceTest', 'CacheManager test: ${cachedValue == 'test_value' ? 'PASSED' : 'FAILED'}');

    // Test RetryService
    try {
      final result = await retryService.executeWithRetryAndFallback<String>(
        operation: () async {
          // This operation should succeed immediately
          return 'success';
        },
        fallbackValue: 'fallback',
        maxRetries: 3,
        operationName: 'testOperation',
      );
      Logger.d('ServiceTest', 'RetryService test: ${result == 'success' ? 'PASSED' : 'FAILED'}');
    } catch (e) {
      Logger.e('ServiceTest', 'RetryService test failed', e);
    }

    // Test PrefetchService
    await prefetchService.trackEventView('test_event_id');
    await prefetchService.trackUserInteraction('test_user_id');
    final status = prefetchService.getPrefetchStatus();
    Logger.d('ServiceTest', 'PrefetchService test: ${status['trackedEvents'] > 0 ? 'PASSED' : 'FAILED'}');

    Logger.d('ServiceTest', 'Service tests completed');
  } catch (e) {
    Logger.e('ServiceTest', 'Error running service tests', e);
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isLoading = true;
  String? _error;
  bool _isSyncing = false;
  bool _hasSyncedThisSession = false;

  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    // Check auth and onboarding status after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndOnboardingStatus();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _handleError(String message, [dynamic error]) {
    Logger.d('Main', '$message: $error');
    setState(() {
      _isLoading = false;
      _error = 'Something went wrong. Please try again later.';
    });
  }

  // Refactored to use Riverpod state management
  Future<void> _checkAuthAndOnboardingStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        NavigationService().navigateToAuthScreen();
        return;
      }

      final data = await FirebaseService().getUserData(user.uid);
      if (data != null && data['onboardingCompleted'] == true) {
        await HiveService().updateOnboardingData(user.uid, data);
        setState(() {
          _isLoading = false;
        });
        NavigationService().navigateToHomeScreen();
      } else {
        setState(() {
          _isLoading = false;
        });
        NavigationService().navigateToOnboardingScreen();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _handleError('Error checking auth and onboarding status', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Yetu\'ga',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorKey: GlobalNavigationService.navigatorKey,
      home: _buildHomeScreen(),
    );
  }

  Widget _buildHomeScreen() {
    Logger.d('Main', 'Building home screen');
    Logger.d('Main', '_isLoading: $_isLoading');
    Logger.d('Main', '_error: $_error');
    Logger.d('Main', '_isSyncing: $_isSyncing');

    // Show syncing screen if we're syncing with Firebase
    if (_isSyncing) {
      Logger.d('Main', 'Syncing with Firebase in the background');
      // Allow partial functionality while syncing
      return const AuthenticatedHomeScreen();
    }

    if (_isLoading) {
      Logger.d('Main', 'Showing loading screen');
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      Logger.d('Main', 'Showing error screen: $_error');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _checkAuthAndOnboardingStatus();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Logger.d('Main', 'No user logged in, showing auth screen');
      return const AuthScreen();
    }

    Logger.d('Main', 'User is logged in: ${user.uid}');

    // Force a sync with Firebase if we haven't done so yet in this session
    if (!_isSyncing && !_hasSyncedThisSession) {
      Logger.d('Main', 'Forcing sync with Firebase');
      _isSyncing = true;

      // Use a post-frame callback to avoid rebuilding during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          Logger.d('Main', 'Syncing with Firebase...');
          // Check Firebase directly
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (doc.exists) {
            final data = doc.data();
            Logger.d('Main', 'User data from Firebase: $data');

            if (data != null && data['onboardingCompleted'] == true) {
              Logger.d('Main', 'Onboarding is completed in Firebase');

              // Update Hive with the onboarding data from Firebase
              try {
                Logger.d('Main', 'Updating Hive with onboarding data from Firebase');
                final onboardingBox = Hive.box<OnboardingData>('onboarding');

                // Create a new OnboardingData object with the data from Firebase
                final onboardingData = OnboardingData()
                  ..accountType = data['accountType']
                  ..displayName = data['displayName']
                  ..username = data['username']
                  ..birthday = data['birthday']?.toDate() // Convert Timestamp to DateTime
                  ..phoneNumber = data['phoneNumber']
                  ..profileImageUrl = data['profileImageUrl']
                  ..interests = List<String>.from(data['interests'] ?? [])
                  ..onboardingCompleted = true;

                // Save to Hive
                await onboardingBox.put(user.uid, onboardingData);
                Logger.d('Main', 'Successfully updated Hive with onboarding data from Firebase');
              } catch (e) {
                Logger.d('Main', 'Error updating Hive: $e');
              }
            }
          }
        } catch (e) {
          Logger.d('Main', 'Error syncing with Firebase: $e');
        } finally {
          // Update state to trigger a rebuild
          if (mounted) {
            setState(() {
              _isSyncing = false;
              _hasSyncedThisSession = true; // Mark that we've synced in this session
            });
          }
        }
      });

      // Show syncing screen while we sync with Firebase
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Syncing with Firebase...'),
            ],
          ),
        ),
      );
    }

    // Check if we have a cached decision about onboarding
    final onboardingBox = Hive.box<OnboardingData>('onboarding');
    final onboardingData = onboardingBox.get(user.uid);

    Logger.d('Main', 'Onboarding data from Hive: $onboardingData');

    if (onboardingData != null && onboardingData.onboardingCompleted) {
      Logger.d('Main', 'Onboarding is completed in Hive, showing home screen');
      return const Scaffold(
        body: AuthenticatedHomeScreen(),
      );
    } else {
      Logger.d('Main', 'Onboarding is not completed in Hive, showing onboarding screen');
      return const OnboardingScreen();
    }
  }
}
