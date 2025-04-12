import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'models/onboarding_data.dart';
import 'models/onboarding_cache.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(OnboardingDataAdapter());
  Hive.registerAdapter(OnboardingCacheAdapter());

  // Clear Hive boxes to force a fresh sync with Firebase
  try {
    print('DEBUG: Clearing Hive boxes to force a fresh sync with Firebase');
    await Hive.deleteBoxFromDisk('onboarding');
    await Hive.deleteBoxFromDisk('onboarding_cache');
  } catch (e) {
    print('DEBUG: Error clearing Hive boxes: $e');
  }

  // Open the boxes
  try {
    await Hive.openBox<OnboardingData>('onboarding');
    await Hive.openBox<OnboardingCache>('onboarding_cache');
    print('DEBUG: Hive boxes opened successfully');
  } catch (e) {
    print('DEBUG: Error opening Hive boxes: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
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

  @override
  void initState() {
    super.initState();
    // Check auth and onboarding status after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndOnboardingStatus();
    });
  }

  Future<void> _checkAuthAndOnboardingStatus() async {
    try {
      print('DEBUG: Checking auth and onboarding status');
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('DEBUG: No user logged in');
        // User is not authenticated, navigate to auth screen
        setState(() {
          _isLoading = false;
        });
      } else {
        print('DEBUG: User is logged in: ${user.uid}');
        // User is authenticated, check if onboarding is completed
        try {
          print('DEBUG: Checking Firebase for onboarding status');
          // Check Firebase directly
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (doc.exists) {
            print('DEBUG: User document exists in Firestore');
            final data = doc.data();
            print('DEBUG: User data: $data');
            if (data != null && data['onboardingCompleted'] == true) {
              print('DEBUG: Onboarding is completed in Firebase');

              // Update Hive with the onboarding data from Firebase
              try {
                print('DEBUG: Updating Hive with onboarding data from Firebase');
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
                print('DEBUG: Successfully updated Hive with onboarding data from Firebase');
              } catch (e) {
                print('DEBUG: Error updating Hive: $e');
                // Continue even if there's an error updating Hive
              }

              // Onboarding is completed, navigate to home screen
              setState(() {
                _isLoading = false;
              });
            } else {
              print('DEBUG: Onboarding is not completed in Firebase');
              // Onboarding is not completed, navigate to onboarding screen
              setState(() {
                _isLoading = false;
              });
            }
          } else {
            print('DEBUG: User document does not exist in Firestore');
            // User document doesn't exist, navigate to onboarding screen
            setState(() {
              _isLoading = false;
            });
          }
        } catch (e) {
          print('DEBUG: Error checking onboarding status: $e');
          // Error checking onboarding status, navigate to onboarding screen
          setState(() {
            _isLoading = false;
            _error = 'Error checking onboarding status: $e';
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error checking auth status: $e');
      // Error checking auth status, show error
      setState(() {
        _isLoading = false;
        _error = 'Error checking auth status: $e';
      });
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
      home: _buildHomeScreen(),
    );
  }

  Widget _buildHomeScreen() {
    print('DEBUG: Building home screen');
    print('DEBUG: _isLoading: $_isLoading');
    print('DEBUG: _error: $_error');
    print('DEBUG: _isSyncing: $_isSyncing');

    // Show syncing screen if we're syncing with Firebase
    if (_isSyncing) {
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

    if (_isLoading) {
      print('DEBUG: Showing loading screen');
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
      print('DEBUG: Showing error screen: $_error');
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
      print('DEBUG: No user logged in, showing auth screen');
      return const AuthScreen();
    }

    print('DEBUG: User is logged in: ${user.uid}');

    // Force a sync with Firebase if we haven't done so yet in this session
    if (!_isSyncing && !_hasSyncedThisSession) {
      print('DEBUG: Forcing sync with Firebase');
      _isSyncing = true;

      // Use a post-frame callback to avoid rebuilding during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          print('DEBUG: Syncing with Firebase...');
          // Check Firebase directly
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (doc.exists) {
            final data = doc.data();
            print('DEBUG: User data from Firebase: $data');

            if (data != null && data['onboardingCompleted'] == true) {
              print('DEBUG: Onboarding is completed in Firebase');

              // Update Hive with the onboarding data from Firebase
              try {
                print('DEBUG: Updating Hive with onboarding data from Firebase');
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
                print('DEBUG: Successfully updated Hive with onboarding data from Firebase');
              } catch (e) {
                print('DEBUG: Error updating Hive: $e');
              }
            }
          }
        } catch (e) {
          print('DEBUG: Error syncing with Firebase: $e');
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

    print('DEBUG: Onboarding data from Hive: $onboardingData');

    if (onboardingData != null && onboardingData.onboardingCompleted) {
      print('DEBUG: Onboarding is completed in Hive, showing home screen');
      return const HomeScreen();
    } else {
      print('DEBUG: Onboarding is not completed in Hive, showing onboarding screen');
      return const OnboardingScreen();
    }
  }
}
