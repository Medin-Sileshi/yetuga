import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../widgets/onboarding_template.dart';

class BirthdayStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BirthdayStep({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends ConsumerState<BirthdayStep> {
  DateTime? _selectedDate;
  String? _error;

  bool _isValidAge(DateTime date) {
    final now = DateTime.now();
    final age = now.year - date.year;
    if (age < 14) return false;
    if (age == 14) {
      if (now.month < date.month ||
          (now.month == date.month && now.day < date.day)) {
        return false;
      }
    }
    return true;
  }

  void _handleDateChange(DateTime date) {
    if (_isValidAge(date)) {
      setState(() {
        _selectedDate = date;
        _error = null;
      });
      ref.read(onboardingProvider.notifier).setBirthday(date);
    } else {
      setState(() {
        _error = 'You must be at least 14 years old';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingTemplate(
      title: 'Your Birthday',
      currentStep: 3,
      totalSteps: 6,
      onNext: _selectedDate != null && _error == null ? widget.onNext : null,
      onBack: widget.onBack,
      onThemeToggle: () {
        ref.read(themeProvider.notifier).toggleTheme();
      },
      content: Column(
        children: [
          const SizedBox(height: 32),

          // Date picker
          SizedBox(
            height: 200,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: DateTime.now().subtract(
                const Duration(days: 365 * 18),
              ),
              maximumDate: DateTime.now().subtract(
                const Duration(days: 365 * 14),
              ),
              minimumDate: DateTime.now().subtract(
                const Duration(days: 365 * 100),
              ),
              onDateTimeChanged: _handleDateChange,
            ),
          ),

          const SizedBox(height: 24),

          // Selected date display
          if (_selectedDate != null) ...[
            Text(
              'Selected date:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
          ],

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Requirements
          Text('Requirements:', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildRequirement(
            'Must be at least 14 years old',
            _selectedDate != null && _isValidAge(_selectedDate!),
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
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
