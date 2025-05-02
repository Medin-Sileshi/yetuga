import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/notification_service.dart';
import '../utils/date_formatter.dart';
import '../utils/logger.dart';
import '../widgets/custom_time_picker.dart';
import 'home_screen.dart';

class EventManagementScreen extends ConsumerStatefulWidget {
  final EventModel event;
  final Function(EventModel) onEventUpdated;
  final VoidCallback onEventDeleted;

  const EventManagementScreen({
    Key? key,
    required this.event,
    required this.onEventUpdated,
    required this.onEventDeleted,
  }) : super(key: key);

  @override
  ConsumerState<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends ConsumerState<EventManagementScreen> {
  late TextEditingController _inquiryController;
  late TextEditingController _attendeeLimitController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late bool _isPrivate;
  late String _activityType;
  bool _isLoading = false;
  bool _hasChanges = false;

  // List of available activity types
  final List<String> _activityTypes = [
    'Celebrate',
    'Drink',
    'Eating',
    'Play',
    'Run',
    'Visit',
    'Walk',
    'Hiking',
    'Dinner',
    'Movie',
    'Watch',
    'Eat',
    'Adventure',
    'Sport',
    'Travel',
    'Gaming',
    'Fitness',
    'Photography',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current event data
    _inquiryController = TextEditingController(text: widget.event.inquiry);
    _attendeeLimitController = TextEditingController(
      text: widget.event.attendeeLimit?.toString() ?? '',
    );
    _selectedDate = widget.event.date;
    _selectedTime = widget.event.time;
    _isPrivate = widget.event.isPrivate;

    // Check if the event's activity type is in our list, if not default to 'Celebrate'
    if (_activityTypes.contains(widget.event.activityType)) {
      _activityType = widget.event.activityType;
    } else {
      _activityType = 'Celebrate';
      Logger.d('EventManagementScreen', 'Activity type "${widget.event.activityType}" not found in list, defaulting to Celebrate');
    }

    // Listen for changes to detect if the form is dirty
    _inquiryController.addListener(_onFormChanged);
    _attendeeLimitController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _inquiryController.dispose();
    _attendeeLimitController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showCustomTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    // Validate form
    if (_inquiryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event description')),
      );
      return;
    }

    // Parse attendee limit
    int? attendeeLimit;
    if (_attendeeLimitController.text.isNotEmpty) {
      try {
        attendeeLimit = int.parse(_attendeeLimitController.text);
        if (attendeeLimit < 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendee limit must be at least 1')),
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid number for attendee limit')),
        );
        return;
      }
    }

    // Check if the new attendee limit is less than the current number of attendees
    if (attendeeLimit != null && attendeeLimit < widget.event.joinedBy.length) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Warning'),
          content: Text(
            'The new attendee limit ($attendeeLimit) is less than the current number of attendees (${widget.event.joinedBy.length}). '
            'Some attendees may be removed. Do you want to continue?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if privacy is changing
      final privacyChanged = _isPrivate != widget.event.isPrivate;

      // Create updated event model
      final updatedEvent = widget.event.copyWith(
        inquiry: _inquiryController.text.trim(),
        date: _selectedDate,
        time: _selectedTime,
        isPrivate: _isPrivate,
        activityType: _activityType,
        attendeeLimit: attendeeLimit,
      );

      // Update the event in Firestore
      final eventService = ref.read(eventServiceProvider);

      // Log the privacy change
      if (privacyChanged) {
        Logger.d('EventManagementScreen', 'Changing event privacy from ${widget.event.isPrivate} to $_isPrivate');
      }

      // Update the event
      await eventService.updateEvent(updatedEvent);

      // If we're changing from private to public, wait a moment to let Firestore propagate the change
      if (privacyChanged && widget.event.isPrivate && !_isPrivate) {
        Logger.d('EventManagementScreen', 'Changed from private to public, waiting for Firestore to propagate');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Notify attendees about the update
      if (_hasSignificantChanges()) {
        final notificationService = ref.read(notificationServiceProvider);
        for (final userId in widget.event.joinedBy) {
          if (userId != eventService.getCurrentUserId()) {
            await notificationService.sendEventUpdateNotification(
              userId: userId,
              event: updatedEvent,
            );
          }
        }
      }

      // Wait for Firestore to propagate the change
      // This helps prevent race conditions with stream listeners
      Logger.d('EventManagementScreen', 'Waiting for Firestore to propagate changes');
      await Future.delayed(const Duration(milliseconds: 300));

      // Store the event locally to avoid any race conditions
      final eventToUpdate = updatedEvent;

      // Call the callback in a try-catch block
      try {
        Logger.d('EventManagementScreen', 'Calling onEventUpdated callback');
        // Use a separate function to avoid any context issues
        _safelyCallEventUpdatedCallback(eventToUpdate);
      } catch (callbackError) {
        Logger.e('EventManagementScreen', 'Error in onEventUpdated callback', callbackError);
      }

      // Show success message and navigate back
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );

        // Wait a bit more before navigating back to ensure all updates are processed
        // Use a separate method to handle navigation to avoid BuildContext issues
        _navigateBackAfterDelay();
      }
    } catch (e) {
      Logger.e('EventManagementScreen', 'Error updating event', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Navigate back after a short delay
  void _navigateBackAfterDelay() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  // Safely call the event updated callback
  void _safelyCallEventUpdatedCallback(EventModel event) {
    // Detach from the current execution context to avoid BuildContext issues
    Future.microtask(() {
      try {
        widget.onEventUpdated(event);
        Logger.d('EventManagementScreen', 'onEventUpdated callback completed successfully');
      } catch (e) {
        Logger.e('EventManagementScreen', 'Error in detached callback', e);
      }
    });
  }

  bool _hasSignificantChanges() {
    // Check if date, time, inquiry, or privacy has changed
    final dateChanged = _selectedDate != widget.event.date;
    final timeChanged = _selectedTime != widget.event.time;
    final inquiryChanged = _inquiryController.text != widget.event.inquiry;
    final privacyChanged = _isPrivate != widget.event.isPrivate;

    // Log changes for debugging
    if (privacyChanged) {
      Logger.d('EventManagementScreen', 'Privacy setting changed from ${widget.event.isPrivate} to $_isPrivate');
    }

    return dateChanged || timeChanged || inquiryChanged || privacyChanged;
  }

  Future<void> _deleteEvent() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text(
          'Are you sure you want to delete this event? '
          'This action cannot be undone and all attendees will be notified.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete the event
      final eventService = ref.read(eventServiceProvider);
      await eventService.deleteEvent(widget.event.id);

      // Notify attendees about the cancellation
      final notificationService = ref.read(notificationServiceProvider);
      for (final userId in widget.event.joinedBy) {
        if (userId != eventService.getCurrentUserId()) {
          await notificationService.sendEventCancellationNotification(
            userId: userId,
            eventTitle: widget.event.inquiry,
          );
        }
      }

      // Call the callback
      widget.onEventDeleted();

      // Show success message and navigate to home screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );

        // Navigate to home screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      Logger.e('EventManagementScreen', 'Error deleting event', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteEvent,
            color: Colors.red,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event description
                  Text('Event Description', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inquiryController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter event description',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Activity type
                  Text('Activity Type', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _activityType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _activityTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _activityType = value;
                          _hasChanges = true;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date and time
                  Text('Date and Time', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Date',
                            ),
                            child: Text(
                              '${DateFormatter.formatMonthShort(_selectedDate)} ${_selectedDate.day}, ${_selectedDate.year}',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Time',
                            ),
                            child: Text(_selectedTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Attendee limit
                  Text('Attendee Limit', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _attendeeLimitController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Leave empty for no limit',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Privacy setting
                  Text('Privacy', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Private Event'),
                    subtitle: const Text(
                      'Private events are only visible to invited users',
                    ),
                    value: _isPrivate,
                    onChanged: (value) {
                      setState(() {
                        _isPrivate = value;
                        _hasChanges = true;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Current attendees
                  Text('Current Attendees (${widget.event.joinedBy.length})',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (widget.event.joinedBy.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No attendees yet'),
                    )
                  else
                    Card(
                      elevation: 2,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.event.joinedBy.length,
                        itemBuilder: (context, index) {
                          final userId = widget.event.joinedBy[index];
                          return FutureBuilder<String>(
                            future: ref.read(eventServiceProvider).getUserDisplayName(userId),
                            builder: (context, snapshot) {
                              final displayName = snapshot.data ?? 'Loading...';
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(displayName.isNotEmpty ? displayName[0] : '?'),
                                ),
                                title: Text(displayName),
                                subtitle: Text(userId == widget.event.userId ? 'Creator' : 'Attendee'),
                                trailing: userId != widget.event.userId
                                    ? IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Colors.red,
                                        onPressed: () => _removeAttendee(userId, displayName),
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_hasChanges ? 'Save Changes' : 'Done'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _removeAttendee(String userId, String displayName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Attendee'),
        content: Text('Are you sure you want to remove $displayName from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Remove the attendee from the event
      final eventService = ref.read(eventServiceProvider);

      // Create a copy of the event with the attendee removed
      final updatedJoinedBy = List<String>.from(widget.event.joinedBy)..remove(userId);
      final updatedEvent = widget.event.copyWith(joinedBy: updatedJoinedBy);

      // Update the event in Firestore
      await eventService.updateEvent(updatedEvent);

      // Notify the removed attendee
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.sendRemovedFromEventNotification(
        userId: userId,
        eventTitle: widget.event.inquiry,
      );

      // Update the local state
      setState(() {
        widget.event.joinedBy.remove(userId);
        _isLoading = false;
      });

      // Call the callback safely
      _safelyCallEventUpdatedCallback(updatedEvent);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$displayName has been removed from the event')),
        );
      }
    } catch (e) {
      Logger.e('EventManagementScreen', 'Error removing attendee', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing attendee: $e')),
        );
      }
    }
  }
}
