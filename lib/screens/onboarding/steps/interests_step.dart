import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_form_provider.dart';

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
  final List<String> _selectedInterests = [];
  final bool _isLoading = false;
  String? _error;

  // Define interests list at the top of the class
  final List<String> _interests = [
    'Adventure',
    'Art',
    'Books',
    'Cars',
    'Cooking',
    'Dancing',
    'Debating',
    'Movies',
    'Music',
    'Sport',
    'TV',
    'Walking',
    'Technology',
    'Travel',
    'Fashion',
    'Gaming',
    'Fitness',
    'Photography',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    final formData = ref.read(onboardingFormProvider);
    if (formData.interests != null) {
      setState(() {
        _selectedInterests.addAll(formData.interests!);
      });
    }
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
      _error = null;
    });

    // Save interests to form provider
    ref.read(onboardingFormProvider.notifier).setInterests(_selectedInterests);
    print('DEBUG: Interests selected: $_selectedInterests');
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 150),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            thickness: 2,
            radius: const Radius.circular(10),
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.0, // Adjusted for larger text
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _interests.length,
              itemBuilder: (context, index) {
                final interest = _interests[index];
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () => _toggleInterest(interest),
                  child: Container(
                    
                    child: Center(
                      child: Text(
                        interest,
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withAlpha(179), // 0.7 opacity
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16, // Increased font size
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _error!,
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 32,
              ),
            ),
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  // Interests list moved to the top of the class
}
