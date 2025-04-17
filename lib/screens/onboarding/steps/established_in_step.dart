import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/business_onboarding_form_provider.dart';
import '../../../providers/onboarding_form_provider.dart';

class EstablishedInStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const EstablishedInStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<EstablishedInStep> createState() => _EstablishedInStepState();
}

class _EstablishedInStepState extends ConsumerState<EstablishedInStep> {
  DateTime? _selectedDate;
  String? _error;
  final int _minYearsAgo = 1;
  final int _maxYearsAgo = 100;

  // Month names for display
  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    final formData = ref.read(businessOnboardingFormProvider);
    if (formData.establishedDate != null) {
      setState(() {
        _selectedDate = formData.establishedDate;
      });
    } else {
      // Set default date to 5 years ago
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(now.year - 5, now.month, 1);
      });
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      // Always set day to 1 for business established date
      _selectedDate = DateTime(date.year, date.month, 1);
      _error = null;
    });

    // Save to both form providers
    ref.read(businessOnboardingFormProvider.notifier).setEstablishedDate(date);
    ref.read(onboardingFormProvider.notifier).setBirthday(date); // Use birthday field for compatibility
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Month wheel (spelled out)
            _buildMonthWheel(
              items: _monthNames,
              selectedValue: _selectedDate != null ? _monthNames[_selectedDate!.month - 1] : null,
              onChanged: (value) {
                if (_selectedDate != null) {
                  _selectDate(DateTime(
                    _selectedDate!.year,
                    _monthNames.indexOf(value) + 1,
                    1, // Always use day 1
                  ));
                }
              },
            ),
            const SizedBox(width: 16),
            // Year wheel
            _buildYearWheel(
              items: List.generate(
                _maxYearsAgo - _minYearsAgo + 1,
                (i) => (DateTime.now().year - _minYearsAgo - i).toString(),
              ),
              selectedValue: _selectedDate?.year.toString(),
              onChanged: (value) {
                if (_selectedDate != null) {
                  _selectDate(DateTime(
                    int.parse(value),
                    _selectedDate!.month,
                    1, // Always use day 1
                  ));
                }
              },
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthWheel({
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 120,
      height: 200,
      child: ListWheelScrollView(
        itemExtent: 60,
        diameterRatio: 2.5,
        perspective: 0.002,
        physics: const FixedExtentScrollPhysics(),
        children: items.map((item) {
          final isSelected = item == selectedValue;
          return Center(
            child: Text(
              item,
              style: TextStyle(
                fontSize: isSelected ? 24 : 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withAlpha(128), // 0.5 opacity
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        onSelectedItemChanged: (index) {
          onChanged(items[index]);
        },
      ),
    );
  }

  Widget _buildYearWheel({
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 80,
      height: 200,
      child: ListWheelScrollView(
        itemExtent: 60,
        diameterRatio: 2.5,
        perspective: 0.002,
        physics: const FixedExtentScrollPhysics(),
        children: items.map((item) {
          final isSelected = item == selectedValue;
          return Center(
            child: Text(
              item,
              style: TextStyle(
                fontSize: isSelected ? 32 : 24,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withAlpha(128), // 0.5 opacity
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
        onSelectedItemChanged: (index) {
          onChanged(items[index]);
        },
      ),
    );
  }
}
