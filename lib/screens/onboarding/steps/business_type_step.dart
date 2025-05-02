import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/business_onboarding_form_provider.dart';
import '../../../providers/onboarding_form_provider.dart';

class BusinessTypeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BusinessTypeStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<BusinessTypeStep> createState() => _BusinessTypeStepState();
}

class _BusinessTypeStepState extends ConsumerState<BusinessTypeStep> {
  final List<String> _selectedTypes = [];
  final bool _isLoading = false;
  String? _error;

  // Define business types list
  final List<String> _businessTypes = [
    'Restaurant',
    'Café',
    'Cinema',
    'Event Organizer',
    'Club',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    final formData = ref.read(businessOnboardingFormProvider);
    if (formData.businessTypes != null) {
      setState(() {
        _selectedTypes.addAll(formData.businessTypes!);
      });
    }
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
      _error = null;
    });

    // Save to both form providers
    ref.read(businessOnboardingFormProvider.notifier).setBusinessTypes(_selectedTypes);
    ref.read(onboardingFormProvider.notifier).setInterests(_selectedTypes); // Use interests field for compatibility
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
              itemCount: _businessTypes.length,
              itemBuilder: (context, index) {
                final type = _businessTypes[index];
                final isSelected = _selectedTypes.contains(type);
                return GestureDetector(
                  onTap: () => _toggleType(type),
                  child: Center(
                    child: Text(
                      type,
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
}
