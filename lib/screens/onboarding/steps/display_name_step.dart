import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_form_provider.dart';
import '../../../providers/business_onboarding_form_provider.dart';
import '../../../providers/firebase_provider.dart';

class DisplayNameStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Function(bool)? onValidityChanged;

  const DisplayNameStep({
    super.key,
    required this.onNext,
    required this.onBack,
    this.onValidityChanged,
  });

  @override
  ConsumerState<DisplayNameStep> createState() => _DisplayNameStepState();
}

class _DisplayNameStepState extends ConsumerState<DisplayNameStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isEditingUsername = false;
  bool _isCheckingUsername = false;
  bool _isUsernameTaken = false;
  bool _isUsernameValid = false;
  bool _isNextButtonEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _loadSavedData() {
    final formData = ref.read(onboardingFormProvider);
    final accountType = formData.accountType;

    // Check if this is a business account
    if (accountType == 'business') {
      final businessFormData = ref.read(businessOnboardingFormProvider);

      if (businessFormData.businessName != null) {
        _nameController.text = businessFormData.businessName!;
      }

      if (businessFormData.username != null) {
        _usernameController.text = businessFormData.username!;
        _isUsernameValid = true;
        _isNextButtonEnabled = true;
        _notifyValidityChanged(true);
      } else if (businessFormData.businessName != null) {
        _generateUsername(businessFormData.businessName!);
      }
    } else {
      // Personal account
      if (formData.displayName != null) {
        _nameController.text = formData.displayName!;
      }

      if (formData.username != null) {
        _usernameController.text = formData.username!;
        _isUsernameValid = true;
        _isNextButtonEnabled = true;
        _notifyValidityChanged(true);
      } else if (formData.displayName != null) {
        _generateUsername(formData.displayName!);
      }
    }
  }

  void _generateUsername(String name) {
    if (name.isEmpty) return;

    // Convert to lowercase and remove spaces
    String username = name.toLowerCase().replaceAll(' ', '');

    // Remove any non-alphanumeric characters
    username = username.replaceAll(RegExp(r'[^\w\s]+'), '');

    setState(() {
      _usernameController.text = username;
      _isUsernameValid = true;
      _isEditingUsername = false;
    });

    // Get account type
    final formData = ref.read(onboardingFormProvider);
    final accountType = formData.accountType;

    // Save the username to the appropriate form provider
    if (accountType == 'business') {
      // Save to both form providers for business accounts
      ref.read(businessOnboardingFormProvider.notifier).setUsername(username);
      ref.read(onboardingFormProvider.notifier).setUsername(username);
    } else {
      // Save to personal form provider
      ref.read(onboardingFormProvider.notifier).setUsername(username);
    }

    // Automatically check username availability
    _checkUsernameAvailability(username);
  }

  void _notifyValidityChanged(bool isValid) {
    print('DEBUG: _notifyValidityChanged called with isValid: $isValid');
    if (widget.onValidityChanged != null) {
      widget.onValidityChanged!(isValid);
      print('DEBUG: Called onValidityChanged callback with: $isValid');
    } else {
      print('DEBUG: onValidityChanged callback is null');
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _isUsernameValid = false;
        _error = 'Username cannot be empty';
        _isNextButtonEnabled = false;
        _isCheckingUsername = false;
      });
      _notifyValidityChanged(false);
      return;
    }

    // Validate username format - now allowing underscores
    if (!RegExp(r'^[a-z0-9_]{2,15}$').hasMatch(username)) {
      setState(() {
        _isUsernameValid = false;
        _error =
            'Username must be 2-15 characters long and contain only lowercase letters, numbers, and underscores';
        _isNextButtonEnabled = false;
        _isCheckingUsername = false;
      });
      _notifyValidityChanged(false);
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _error = null;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final isAvailable = await firebaseService.isUsernameAvailable(username);

      setState(() {
        _isUsernameTaken = !isAvailable;
        _isUsernameValid = isAvailable;
        _error = isAvailable ? null : 'Username is already taken';
        _isEditingUsername = false;
        _isNextButtonEnabled = isAvailable && _nameController.text.isNotEmpty;
        _isCheckingUsername = false;
      });

      // Save the username to the form provider if it's valid
      if (isAvailable) {
        ref.read(onboardingFormProvider.notifier).setUsername(username);
      }

      _notifyValidityChanged(_isNextButtonEnabled);
    } catch (e) {
      setState(() {
        _error = 'Error checking username: $e';
        _isUsernameValid = false;
        _isNextButtonEnabled = false;
        _isCheckingUsername = false;
      });
      _notifyValidityChanged(false);
    }
  }

  // This method is now public so it can be called from the onboarding screen
  void validateAndSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_isUsernameValid) {
        setState(() {
          _error = 'Please enter a valid username';
        });
        return;
      }

      // Save the display name and username
      final displayName = _nameController.text;
      final username = _usernameController.text;

      try {
        // Get account type
        final formData = ref.read(onboardingFormProvider);
        final accountType = formData.accountType;

        if (accountType == 'business') {
          // For business accounts, save to both form providers
          ref.read(businessOnboardingFormProvider.notifier).setBusinessName(displayName);
          ref.read(businessOnboardingFormProvider.notifier).setUsername(username);

          // Also save to personal form provider for compatibility
          ref.read(onboardingFormProvider.notifier).setDisplayName(displayName);
          ref.read(onboardingFormProvider.notifier).setUsername(username);

          print('DEBUG: Business name saved: $displayName');
          print('DEBUG: Business username saved: $username');
        } else {
          // For personal accounts, save to personal form provider
          ref.read(onboardingFormProvider.notifier).setDisplayName(displayName);
          ref.read(onboardingFormProvider.notifier).setUsername(username);

          print('DEBUG: Display name saved: $displayName');
          print('DEBUG: Username saved: $username');
        }

        // Call onNext to navigate to the next page
        widget.onNext();
      } catch (e) {
        setState(() {
          _error = 'Failed to save data: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                label: const Center(child: Text('name')),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _isNextButtonEnabled = value.isNotEmpty && _isUsernameValid;
                });
                _notifyValidityChanged(_isNextButtonEnabled);

                // Always generate username from the name unless user has manually edited it
                if (!_isEditingUsername) {
                  _generateUsername(value);
                }

                // Save the display name to the form provider
                ref.read(onboardingFormProvider.notifier).setDisplayName(value);
              },
            ),
            Container(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: 6),
            // Username Field
            Row(
              children: [
                const Text(
                  '@ ',
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: _isEditingUsername
                      ? TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            // label: const Text('username'),
                            labelStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          ),
                          textAlign: TextAlign.left,
                          style: const TextStyle(fontSize: 14),
                          onChanged: (value) {
                            // Don't check availability on every keystroke
                            setState(() {
                              _isUsernameValid = false;
                              _isNextButtonEnabled = false;
                            });
                            _notifyValidityChanged(false);
                          },
                        )
                      : Text(
                          _usernameController.text.isEmpty
                              ? 'username'
                              : _usernameController.text,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(153), // 0.6 opacity
                          ),
                        ),
                ),
                if (_isCheckingUsername)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF29C7E4)),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      _isEditingUsername ? Icons.check : Icons.edit,
                      color: const Color(0xFF29C7E4),
                      size: 16,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_isEditingUsername) {
                          _checkUsernameAvailability(
                              _usernameController.text);
                        } else {
                          _isEditingUsername = true;
                        }
                      });
                    },
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
