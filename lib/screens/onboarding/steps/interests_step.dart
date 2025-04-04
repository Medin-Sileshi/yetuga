import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/firebase_provider.dart';
import '../../../widgets/onboarding_template.dart';

class InterestsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const InterestsStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<InterestsStep> createState() => _InterestsStepState();
}

class _InterestsStepState extends ConsumerState<InterestsStep> {
  bool _isSubmitting = false;
  String? _error;

  final List<String> _interests = [
    'Technology',
    'Business',
    'Education',
    'Health',
    'Sports',
    'Entertainment',
    'Food',
    'Travel',
    'Fashion',
    'Art',
    'Music',
    'Science',
  ];

  Set<String> _selectedInterests = {};

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  Future<void> _submitOnboarding() async {
    if (_selectedInterests.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final onboardingData = ref.read(onboardingProvider);
      final firebaseService = ref.read(firebaseServiceProvider);

      // Save user profile data to Firebase
      await firebaseService.saveUserProfile(
        accountType: onboardingData.accountType,
        displayName: onboardingData.displayName,
        username: onboardingData.username,
        birthday: onboardingData.birthday,
        phoneNumber: onboardingData.phoneNumber,
        profileImageUrl: onboardingData.profileImageUrl,
        interests: _selectedInterests.toList(),
      );

      // Mark onboarding as complete
      ref.read(onboardingProvider.notifier).completeOnboarding();

      // Navigate to home screen
      widget.onNext();
    } catch (e) {
      setState(() {
        _error = 'Failed to save profile. Please try again.';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      title: 'Your Interests',
      currentStep: 6,
      totalSteps: 6,
      onNext: _selectedInterests.isNotEmpty ? _submitOnboarding : null,
      onBack: widget.onBack,
      onThemeToggle: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      content: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 32),

              // Error message
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Selected interests count
              Text(
                '${_selectedInterests.length} interests selected',
                style: Theme.of(context).textTheme.titleSmall,
              ),

              const SizedBox(height: 24),

              // Interests grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _interests.length,
                  itemBuilder: (context, index) {
                    final interest = _interests[index];
                    final isSelected = _selectedInterests.contains(interest);
                    return InkWell(
                      onTap: () => _toggleInterest(interest),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            interest,
                            style: TextStyle(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Requirements
              Text(
                'Requirements:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildRequirement(
                'Select at least one interest',
                _selectedInterests.isNotEmpty,
              ),
            ],
          ),

          // Loading overlay
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: isMet
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
