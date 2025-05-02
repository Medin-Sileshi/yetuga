import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';
import '../utils/date_formatter.dart';

class EventInfoWidget extends StatefulWidget {
  final String eventId;

  const EventInfoWidget({Key? key, required this.eventId}) : super(key: key);

  @override
  State<EventInfoWidget> createState() => _EventInfoWidgetState();
}

class _EventInfoWidgetState extends State<EventInfoWidget> {
  StreamSubscription<DocumentSnapshot>? _eventSubscription;
  EventModel? _event;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscribeToEvent();
  }

  @override
  void didUpdateWidget(EventInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _unsubscribe();
      _subscribeToEvent();
    }
  }

  void _subscribeToEvent() {
    setState(() {
      _isLoading = true;
      _error = null;
      _event = null;
    });

    try {
      final eventRef = FirebaseFirestore.instance.collection('events').doc(widget.eventId);
      _eventSubscription = eventRef.snapshots().listen(
        (snapshot) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
            if (snapshot.exists) {
              try {
                _event = EventModel.fromFirestore(snapshot);
                _error = null;
              } catch (e) {
                Logger.e('EventInfoWidget', 'Error parsing event data', e);
                _event = null;
                _error = 'Error parsing event data: $e';
              }
            } else {
              _event = null;
              _error = 'Event not found';
            }
          });
        },
        onError: (error) {
          if (!mounted) return;

          Logger.e('EventInfoWidget', 'Error fetching event', error);
          setState(() {
            _isLoading = false;
            _event = null;
            _error = 'Error fetching event: $error';
          });
        }
      );
    } catch (e) {
      Logger.e('EventInfoWidget', 'Error setting up event subscription', e);
      setState(() {
        _isLoading = false;
        _event = null;
        _error = 'Error setting up event subscription: $e';
      });
    }
  }

  void _unsubscribe() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle loading state
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 12.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Handle error state
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Text(_error!),
      );
    }

    // Handle no data
    if (_event == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12.0),
        child: Text('Event not found'),
      );
    }

    // Display event data
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Event: ${_event!.inquiry}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_event!.activityType} on ${DateFormatter.formatMonthShort(_event!.date)} ${_event!.date.day} @ ${_event!.time.format(context)}',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
