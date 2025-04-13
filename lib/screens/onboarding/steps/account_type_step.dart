import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_form_provider.dart';
import '../../../providers/business_onboarding_form_provider.dart';

class AccountTypeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final String backButtonLabel;

  const AccountTypeStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.backButtonLabel,
  });

  @override
  ConsumerState<AccountTypeStep> createState() => _AccountTypeStepState();
}

class _AccountTypeStepState extends ConsumerState<AccountTypeStep> {
  String? _selectedType;
  String? _selectedDescription;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    final formData = ref.read(onboardingFormProvider);
    if (formData.accountType != null) {
      setState(() {
        _selectedType = formData.accountType;
        _selectedDescription = _getDescription(formData.accountType!);
      });
    }
  }

  String _getDescription(String type) {
    switch (type) {
      case 'personal':
        return 'Perfect for individual users who want to connect with others and share their experiences.';
      case 'business':
        return 'Ideal for businesses looking to establish their presence and engage with customers.';
      default:
        return '';
    }
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
      _selectedDescription = _getDescription(type);
    });

    // Update both form providers
    ref.read(onboardingFormProvider.notifier).setAccountType(type);

    // Also update the business form provider if this is a business account
    if (type == 'business') {
      ref.read(businessOnboardingFormProvider.notifier).setAccountType(type);
    }

    // Force a rebuild of the parent widget to update the Next button
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // This will force the parent to rebuild
        setState(() {});

        // Try to trigger the next button directly
        if (_selectedType != null && _selectedType!.isNotEmpty) {
          print('DEBUG: Trying to force next button update');
          // This is a hack to force the parent to check the form data again
          final formData = ref.read(onboardingFormProvider);
          if (formData.accountType != null && formData.accountType!.isNotEmpty) {
            print('DEBUG: Account type is set in form data: ${formData.accountType}');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTypeButton('Personal', 'personal'),
            const SizedBox(width: 16),
            _buildTypeButton('Business', 'business'),
          ],
        ),
        if (_selectedDescription != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedDescription!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),

        ],
      ],
    );
  }

  Widget _buildTypeButton(String label, String type) {
    final isSelected = _selectedType == type;
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: () => _selectType(type),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.primary : null,
            ),
      ),
    );
  }
}
