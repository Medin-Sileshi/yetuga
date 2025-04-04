import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/onboarding_template.dart';

class PhoneStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PhoneStep({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<PhoneStep> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String? _error;

  void _validateAndUpdate() {
    if (_formKey.currentState?.validate() ?? false) {
      final phoneNumber = _phoneController.text.trim();
      setState(() {
        _error = null;
      });
      ref.read(onboardingProvider.notifier).setPhoneNumber(phoneNumber);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      title: 'Your Phone Number',
      currentStep: 4,
      totalSteps: 6,
      onNext:
          _phoneController.text.isNotEmpty && _error == null
              ? widget.onNext
              : null,
      onBack: widget.onBack,
      onThemeToggle: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phone number field
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: const UnderlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                alignLabelWithHint: true,
                prefixText: '+251 ',
                hintText: '9XXXXXXXX',
              ),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!value.startsWith('9')) {
                  return 'Phone number must start with 9';
                }
                if (value.length != 9) {
                  return 'Phone number must be 9 digits';
                }
                return null;
              },
              onChanged: (value) {
                if (_formKey.currentState?.validate() ?? false) {
                  _validateAndUpdate();
                }
              },
            ),

            const SizedBox(height: 24),

            // Example format
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Example format:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+251 9XXXXXXXX',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Privacy notice
            Text(
              'Your phone number will be used for:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildPrivacyItem('Account verification'),
            _buildPrivacyItem('Password recovery'),
            _buildPrivacyItem('Important notifications'),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
