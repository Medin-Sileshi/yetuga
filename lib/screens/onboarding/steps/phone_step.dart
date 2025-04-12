import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_form_provider.dart';

class PhoneStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Function(bool) onValidityChanged;

  const PhoneStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onValidityChanged,
  });

  @override
  ConsumerState<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<PhoneStep> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String? _error;
  final String _countryCode = '+251';
  final String _exampleNumber = '912345678';
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _loadSavedData() {
    final formData = ref.read(onboardingFormProvider);
    if (formData.phoneNumber != null) {
      // Remove country code if it exists in saved data
      String savedNumber = formData.phoneNumber!;
      if (savedNumber.startsWith(_countryCode)) {
        savedNumber = savedNumber.substring(_countryCode.length);
      }
      _phoneController.text = savedNumber;
      _validateInput(savedNumber);
    }
  }

  void _validateInput(String value) {
    bool isValid = value.length == 9 && value.startsWith('9');
    print('DEBUG: Phone _validateInput called with value: $value, isValid: $isValid');
    setState(() {
      _isValid = isValid;
    });
    widget.onValidityChanged(isValid);
    print('DEBUG: Called phone onValidityChanged with: $isValid');
  }

  // This method is now public so it can be called from the onboarding screen
  void validateAndSave() {
    if (_formKey.currentState?.validate() ?? false) {
      // Get the phone number without any formatting
      final phoneNumberOnly = _phoneController.text.trim();

      // Make sure it starts with 9 (Ethiopian format)
      if (!phoneNumberOnly.startsWith('9')) {
        setState(() {
          _error = 'Phone number must start with 9';
        });
        return;
      }

      // Combine country code with phone number
      final fullPhoneNumber = '$_countryCode$phoneNumberOnly';
      print('DEBUG: Phone number to save: $fullPhoneNumber');

      // Save to provider
      ref.read(onboardingFormProvider.notifier).setPhoneNumber(fullPhoneNumber);
      print('DEBUG: Phone number saved: $fullPhoneNumber');

      // Verify the data was saved by reading it back
      final formData = ref.read(onboardingFormProvider);
      print('DEBUG: Verification - Phone number in provider: ${formData.phoneNumber}');

      // Call onNext to navigate to the next page
      widget.onNext();
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
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              decoration: InputDecoration(
                label: const Center(child: Text('Phone Number')),
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
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                prefixText: '🇪🇹 $_countryCode ',
                prefixStyle: const TextStyle(
                  fontSize: 16,
                ),
                hintText: _exampleNumber,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (value.length != 9) {
                  return 'Phone number must be 9 digits';
                }
                if (!value.startsWith('9')) {
                  return 'Phone number must start with 9';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _error = null;
                });
                _validateInput(value);

                // Save to provider if valid
                if (_isValid) {
                  final fullPhoneNumber = '$_countryCode$value';
                  ref.read(onboardingFormProvider.notifier).setPhoneNumber(fullPhoneNumber);
                }
              },
              onFieldSubmitted: (_) => validateAndSave(),
            ),
            Container(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Text(
              'Example: 🇪🇹 $_countryCode $_exampleNumber',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(153), // 0.6 opacity
                  ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }


}
