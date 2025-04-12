import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/onboarding_form_provider.dart';

class BirthdayStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BirthdayStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends ConsumerState<BirthdayStep> {
  DateTime? _selectedDate;
  String? _error;
  final int _minAge = 14;
  final int _maxAge = 100;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    final formData = ref.read(onboardingFormProvider);
    if (formData.birthday != null) {
      setState(() {
        _selectedDate = formData.birthday;
      });
    } else {
      // Set default date to 18 years ago
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(now.year - 18, now.month, now.day);
      });
    }
  }

  bool _isValidAge(DateTime date) {
    final now = DateTime.now();
    final age = now.year - date.year;
    if (now.month < date.month ||
        (now.month == date.month && now.day < date.day)) {
      return age - 1 >= _minAge;
    }
    return age >= _minAge;
  }

  void _selectDate(DateTime date) {
    if (!_isValidAge(date)) {
      setState(() {
        _error = 'You must be at least $_minAge years old';
      });
      return;
    }

    setState(() {
      _selectedDate = date;
      _error = null;
    });
    ref.read(onboardingFormProvider.notifier).setBirthday(date);
    print('DEBUG: Birthday selected: $date');
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDateWheel(
              items: List.generate(31, (i) => (i + 1).toString()),
              selectedValue: _selectedDate?.day.toString(),
              onChanged: (value) {
                if (_selectedDate != null) {
                  _selectDate(DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    int.parse(value),
                  ));
                }
              },
            ),
            const SizedBox(width: 16),
            _buildDateWheel(
              items:
                  List.generate(12, (i) => (i + 1).toString().padLeft(2, '0')),
              selectedValue: _selectedDate?.month.toString().padLeft(2, '0'),
              onChanged: (value) {
                if (_selectedDate != null) {
                  _selectDate(DateTime(
                    _selectedDate!.year,
                    int.parse(value),
                    _selectedDate!.day,
                  ));
                }
              },
            ),
            const SizedBox(width: 16),
            _buildDateWheel(
              items: List.generate(
                _maxAge - _minAge + 1,
                (i) => (DateTime.now().year - _minAge - i).toString(),
              ),
              selectedValue: _selectedDate?.year.toString(),
              onChanged: (value) {
                if (_selectedDate != null) {
                  _selectDate(DateTime(
                    int.parse(value),
                    _selectedDate!.month,
                    _selectedDate!.day,
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

  Widget _buildDateWheel({
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
