import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../utils/logger.dart';

class CreateEventSheet extends ConsumerStatefulWidget {
  const CreateEventSheet({super.key});

  @override
  ConsumerState<CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends ConsumerState<CreateEventSheet> {
  // Activity types
  final List<String> _activityTypes = ['Walk', 'Run', 'Visit','Eat', 'Celebrate','Watch', 'Play', 'Drink'];
  String _selectedActivity = 'Watch';

  // Text controller for user inquiry
  final TextEditingController _inquiryController = TextEditingController();

  // Text controller for attendee limit
  final TextEditingController _attendeeLimitController = TextEditingController();

  // Date and time
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  // Privacy toggle
  bool _isPrivate = true;

  // Loading state
  bool _isLoading = false;

  // Error message
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Always set to current date and time when opened
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _inquiryController.dispose();
    _attendeeLimitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final hintColor = textColor.withAlpha(153); // 0.6 opacity
    final borderColor = theme.dividerColor;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              // Add extra padding at the bottom to account for the keyboard
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Header with back button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                color: textColor,
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Going Out\nWhat's On\nYour Mind?",
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : primaryColor,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
            // Activity selector and user inquiry
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Activity type selector (vertical wheel)
                SizedBox(
                  width: 100,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Center indicator line
                      Positioned(
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 40,
                        ),
                      ),
                      // Scrollable wheel
                      ListWheelScrollView.useDelegate(
                        itemExtent: 40, // Height of each item
                        perspective: 0.005, // Subtle 3D effect
                        diameterRatio: 1.5, // Tighter curve
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            _selectedActivity =
                                _activityTypes[index % _activityTypes.length];
                          });
                        },
                        childDelegate: ListWheelChildLoopingListDelegate(
                          children: List.generate(
                            1000, // Large number to give the illusion of infinite scrolling
                            (index) {
                              final actualIndex = index % _activityTypes.length;
                              final activity = _activityTypes[actualIndex];
                              final isSelected = activity == _selectedActivity;

                              return Center(
                                child: Text(
                                  activity,
                                  style: TextStyle(
                                    color:
                                        isSelected ? textColor : hintColor,
                                    fontSize: isSelected ? 18 : 16,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // User inquiry field - aligned with the center of the wheel
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _inquiryController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "user inquery",
                          hintStyle: TextStyle(color: hintColor),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: primaryColor),
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Date and time pickers
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time picker with scrollable wheels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 100,
                        child: Row(
                          children: [
                            // Hour wheel
                            Expanded(
                              flex: 2,
                              child: _buildTimeWheel(
                                List.generate(
                                    12,
                                    (index) =>
                                        (index + 1).toString().padLeft(2, '0')),
                                _selectedTime.hourOfPeriod == 0
                                    ? 11
                                    : _selectedTime.hourOfPeriod - 1,
                                (value) {
                                  final newHour = int.parse(value);
                                  final newTime = TimeOfDay(
                                    hour: _selectedTime.period == DayPeriod.am
                                        ? (newHour == 12 ? 0 : newHour)
                                        : (newHour == 12 ? 12 : newHour + 12),
                                    minute: _selectedTime.minute,
                                  );
                                  setState(() {
                                    _selectedTime = newTime;
                                  });
                                },
                              ),
                            ),

                            // Separator
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Minute wheel
                            Expanded(
                              flex: 2,
                              child: _buildTimeWheel(
                                List.generate(
                                    60,
                                    (index) =>
                                        index.toString().padLeft(2, '0')),
                                _selectedTime.minute,
                                (value) {
                                  final newMinute = int.parse(value);
                                  final newTime = TimeOfDay(
                                    hour: _selectedTime.hour,
                                    minute: newMinute,
                                  );
                                  setState(() {
                                    _selectedTime = newTime;
                                  });
                                },
                              ),
                            ),

                            // AM/PM wheel
                            Expanded(
                              flex: 2,
                              child: _buildTimeWheel(
                                ['AM', 'PM'],
                                _selectedTime.period == DayPeriod.am ? 0 : 1,
                                (value) {
                                  final newPeriod = value == 'AM'
                                      ? DayPeriod.am
                                      : DayPeriod.pm;
                                  if (newPeriod != _selectedTime.period) {
                                    final hourOfPeriod =
                                        _selectedTime.hourOfPeriod == 0
                                            ? 12
                                            : _selectedTime.hourOfPeriod;
                                    final newHour = newPeriod == DayPeriod.am
                                        ? (hourOfPeriod == 12
                                            ? 0
                                            : hourOfPeriod)
                                        : (hourOfPeriod == 12
                                            ? 12
                                            : hourOfPeriod + 12);
                                    final newTime = TimeOfDay(
                                      hour: newHour,
                                      minute: _selectedTime.minute,
                                    );
                                    setState(() {
                                      _selectedTime = newTime;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Date picker with scrollable wheels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 100,
                        child: Row(
                          children: [
                            // Day wheel
                            Expanded(
                              flex: 1,
                              child: _buildTimeWheel(
                                List.generate(
                                    31,
                                    (index) =>
                                        (index + 1).toString().padLeft(2, '0')),
                                _selectedDate.day - 1,
                                (value) {
                                  final newDay = int.parse(value);
                                  final newDate = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month,
                                    newDay,
                                  );
                                  setState(() {
                                    _selectedDate = newDate;
                                  });
                                },
                              ),
                            ),

                            // Separator
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '/',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Month wheel with short month names
                            Expanded(
                              flex: 2, // Wider to accommodate text
                              child: _buildTimeWheel(
                                const [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Aug',
                                  'Sep',
                                  'Oct',
                                  'Nov',
                                  'Dec'
                                ],
                                _selectedDate.month - 1,
                                (value) {
                                  // Convert month name to month number (1-12)
                                  const monthNames = [
                                    'Jan',
                                    'Feb',
                                    'Mar',
                                    'Apr',
                                    'May',
                                    'Jun',
                                    'Jul',
                                    'Aug',
                                    'Sep',
                                    'Oct',
                                    'Nov',
                                    'Dec'
                                  ];
                                  final newMonth =
                                      monthNames.indexOf(value) + 1;

                                  final newDate = DateTime(
                                    _selectedDate.year,
                                    newMonth,
                                    _selectedDate.day >
                                            DateTime(_selectedDate.year,
                                                    newMonth + 1, 0)
                                                .day
                                        ? DateTime(_selectedDate.year,
                                                newMonth + 1, 0)
                                            .day
                                        : _selectedDate.day,
                                  );
                                  setState(() {
                                    _selectedDate = newDate;
                                  });
                                },
                              ),
                            ),

                            // Separator
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '/',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Year wheel - only current year and next year
                            Expanded(
                              flex: 1,
                              child: _buildTimeWheel(
                                [
                                  DateTime.now().year.toString().substring(
                                      2), // Current year (last 2 digits)
                                  (DateTime.now().year + 1)
                                      .toString()
                                      .substring(
                                          2), // Next year (last 2 digits)
                                ],
                                _selectedDate.year == DateTime.now().year
                                    ? 0
                                    : 1, // Select current index
                                (value) {
                                  final newYear = int.parse('20$value');
                                  final newDate = DateTime(
                                    newYear,
                                    _selectedDate.month,
                                    _selectedDate.day >
                                            DateTime(newYear,
                                                    _selectedDate.month + 1, 0)
                                                .day
                                        ? DateTime(newYear,
                                                _selectedDate.month + 1, 0)
                                            .day
                                        : _selectedDate.day,
                                  );
                                  setState(() {
                                    _selectedDate = newDate;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Privacy toggle and Attendee limit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Privacy toggle
                Row(
                  children: [
                    Switch(
                      value: _isPrivate,
                      onChanged: (value) {
                        setState(() {
                          _isPrivate = value;
                        });
                      },
                      activeColor: primaryColor,
                      activeTrackColor: primaryColor.withAlpha(102), // 0.4 opacity
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Private Event',
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                  ],
                ),
                
                // Attendee limit field
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24.0),
                    child: Row(
                      children: [
                        Text(
                          'Limit:',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _attendeeLimitController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: "No limit",
                              hintStyle: TextStyle(color: hintColor),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: primaryColor),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        Text(
                          'People',
                          style: TextStyle(color: textColor, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 8),

            // Create button (similar to onboarding next button)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  // Validate inputs
                  if (_inquiryController.text.trim().isEmpty) {
                    setState(() {
                      _errorMessage = 'Please enter your inquiry';
                    });
                    return;
                  }

                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });

                  try {
                    Logger.d('CreateEventSheet', 'Creating new event...');

                    // Parse attendee limit if provided
                    int? attendeeLimit;
                    if (_attendeeLimitController.text.isNotEmpty) {
                      try {
                        attendeeLimit = int.parse(_attendeeLimitController.text.trim());
                        if (attendeeLimit <= 0) {
                          throw Exception('Attendee limit must be a positive number');
                        }
                      } catch (e) {
                        setState(() {
                          _errorMessage = 'Please enter a valid number for attendee limit';
                          _isLoading = false;
                        });
                        return;
                      }
                    }

                    // Create event model
                    final event = EventModel(
                      userId: '', // Will be set by the service
                      activityType: _selectedActivity,
                      inquiry: _inquiryController.text.trim(),
                      date: _selectedDate,
                      time: _selectedTime,
                      isPrivate: _isPrivate,
                      attendeeLimit: attendeeLimit,
                    );

                    Logger.d('CreateEventSheet', 'Event model created: ${event.toMap()}');

                    // Get the event service
                    final eventService = ref.read(eventServiceProvider);

                    // Add the event to Firestore
                    Logger.d('CreateEventSheet', 'Adding event to Firestore...');
                    await eventService.addEvent(event);
                    Logger.d('CreateEventSheet', 'Event added successfully');

                    // Close the sheet if still mounted
                    if (mounted) {
                      // Use a new function to avoid BuildContext across async gaps
                      _closeSheet();
                    }
                  } catch (e) {
                    Logger.e('CreateEventSheet', 'Error creating event', e);
                    setState(() {
                      _errorMessage = 'Failed to create event: ${e.toString()}';
                      _isLoading = false;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(
                        'CREATE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to close the sheet safely
  void _closeSheet() {
    Navigator.pop(context);
  }

  // Helper method to build a scrollable wheel for time/date selection
  Widget _buildTimeWheel<T>(
      List<T> items, int initialIndex, Function(T) onChanged) {
    // Ensure initialIndex is within bounds
    initialIndex = initialIndex.clamp(0, items.length - 1);

    // Get theme colors for the wheel
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final hintColor = textColor.withAlpha(153); // 0.6 opacity

    // Create a scroll controller for this wheel
    final controller = FixedExtentScrollController(initialItem: initialIndex);

    // Use Future.microtask to ensure the wheel is properly positioned after build
    Future.microtask(() {
      if (controller.hasClients) {
        controller.jumpToItem(initialIndex);
      }
    });

    return Stack(
      alignment: Alignment.center,
      children: [
        // Center indicator line
        Positioned(
          left: 0,
          right: 0,
          child: Container(
            height: 40,

          ),
        ),
        // Scrollable wheel
        ListWheelScrollView(
          controller: controller,
          itemExtent: 40, // Height of each item
          perspective: 0.005, // Subtle 3D effect
          diameterRatio: 1.5, // Tighter curve
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            onChanged(items[index]);
          },
          children: List.generate(
            items.length,
            (index) {
              final item = items[index];
              final isSelected = index == initialIndex;

              return Center(
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    color: isSelected ? textColor : hintColor,
                    fontSize: isSelected ? 18 : 16,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
