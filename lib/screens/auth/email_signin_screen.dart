import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_validator/form_validator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/auth_page_template.dart';
import '../home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import 'create_account_screen.dart';
import '../../providers/onboarding_provider.dart';

class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (mounted) {
        // Show loading dialog for checking onboarding status
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking onboarding status...'),
              ],
            ),
          ),
        );

        try {
          // Check Firebase directly for onboarding status
          final firebaseService = ref.read(firebaseServiceProvider);
          final userProfile = await firebaseService.getUserProfile();
          print('DEBUG: User profile from Firebase: $userProfile');

          // Close the loading dialog
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          if (userProfile != null && userProfile['onboardingCompleted'] == true) {
            print('DEBUG: Onboarding is completed in Firebase, navigating to home screen');

            // Update Hive with the onboarding data from Firebase
            try {
              print('DEBUG: Updating Hive with onboarding data from Firebase');
              final onboardingNotifier = ref.read(onboardingProvider.notifier);

              // Create a new OnboardingData object with the data from Firebase
              final onboardingData = OnboardingData()
                ..accountType = userProfile['accountType']
                ..displayName = userProfile['displayName']
                ..username = userProfile['username']
                ..birthday = userProfile['birthday']?.toDate() // Convert Timestamp to DateTime
                ..phoneNumber = userProfile['phoneNumber']
                ..profileImageUrl = userProfile['profileImageUrl']
                ..interests = List<String>.from(userProfile['interests'] ?? [])
                ..onboardingCompleted = true;

              // Save to Hive
              await onboardingNotifier.saveData(onboardingData);
              print('DEBUG: Successfully updated Hive with onboarding data from Firebase');
            } catch (e) {
              print('DEBUG: Error updating Hive: $e');
              // Continue even if there's an error updating Hive
            }

            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            }
          } else {
            print('DEBUG: Onboarding is not completed in Firebase, navigating to onboarding screen');
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            }
          }
        } catch (e) {
          print('DEBUG: Error checking Firebase for onboarding status: $e');
          // Close the loading dialog if it's still open
          if (context.mounted) {
            Navigator.of(context).pop();
          }

          // Fall back to checking the onboarding provider
          final onboardingState = ref.read(onboardingProvider);
          onboardingState.when(
            data: (data) {
              if (data.isComplete()) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (route) => false,
                );
              } else {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                  (route) => false,
                );
              }
            },
            loading: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            },
            error: (error, stack) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingScreen()),
                (route) => false,
              );
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password reset email sent. Please check your inbox.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageTemplate(
      title: 'Sign in here',
      showBackButton: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                label: Center(child: Text('Email')),
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.zero,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.zero,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                alignLabelWithHint: true,
              ),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.emailAddress,
              validator: ValidationBuilder()
                  .required('Email is required')
                  .email('Please enter a valid email')
                  .build(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child:
                  Container(height: 1, color: Theme.of(context).dividerColor),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 90.0),
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            label: Center(child: Text('Password')),
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.zero,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.zero,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.zero,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 16),
                            alignLabelWithHint: true,
                          ),
                          textAlign: TextAlign.center,
                          obscureText: !_showPassword,
                          validator: ValidationBuilder()
                              .required('Password is required')
                              .build(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 36.0),
                        child: Container(
                            height: 1, color: Theme.of(context).dividerColor),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 36.0),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign In'),
            ),
          ],
        ),
      ),
      bottomButtons: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateAccountScreen(),
                    ),
                  ),
          child: const Text("Don't have an account yet? Create one here"),
        ),
      ],
    );
  }
}
