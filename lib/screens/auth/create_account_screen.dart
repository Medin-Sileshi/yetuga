import 'package:flutter/material.dart';
import 'package:form_validator/form_validator.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_page_template.dart';
import '../../utils/password_validator.dart';
import '../home_screen.dart';
import '../../providers/onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../onboarding/onboarding_screen.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, bool> _passwordValidation = {};
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _passwordValidation = PasswordValidator.validatePassword('');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordValidation(String password) {
    setState(() {
      _passwordValidation = PasswordValidator.validatePassword(password);
    });
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await authService.createAccount(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted && userCredential.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Check onboarding status and navigate accordingly
        final onboardingState = ref.read(onboardingProvider);
        if (onboardingState.isComplete) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create account: ${e.toString()}'),
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

  Widget _buildPasswordRequirement(String label, bool isValid) {
    return isValid
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Icon(Icons.cancel, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageTemplate(
      title: 'Sign up here',
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
                          onChanged: _updatePasswordValidation,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (!PasswordValidator.isPasswordValid(value)) {
                              return 'Password does not meet requirements';
                            }
                            return null;
                          },
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 90.0),
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            label: Center(child: Text('Confirm Password')),
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
                          obscureText: !_showConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
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
                        _showConfirmPassword = !_showConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _showConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordRequirement(
                    'Minimum 6 characters',
                    _passwordValidation['minLength'] ?? false,
                  ),
                  _buildPasswordRequirement(
                    'At least one uppercase letter (A-Z)',
                    _passwordValidation['uppercase'] ?? false,
                  ),
                  _buildPasswordRequirement(
                    'At least one lowercase letter (a-z)',
                    _passwordValidation['lowercase'] ?? false,
                  ),
                  _buildPasswordRequirement(
                    'At least one number (0-9)',
                    _passwordValidation['number'] ?? false,
                  ),
                  _buildPasswordRequirement(
                    'At least one symbol (!@#\$%^&*)',
                    _passwordValidation['symbol'] ?? false,
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _createAccount,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
      bottomButtons: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text("Already have an account? Sign in here"),
        ),
      ],
    );
  }
}
