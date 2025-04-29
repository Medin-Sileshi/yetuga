import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EventModel {
  final String id;
  final String userId;
  final String activityType;
  final String inquiry;
  final DateTime date;
  final TimeOfDay time;
  final bool isPrivate;
  final DateTime createdAt;
  List<String> likedBy;
  List<String> joinedBy;
  final int? attendeeLimit;
  final bool isInvited; // Flag to indicate if the current user was invited to this event

  EventModel({
    this.id = '',
    required this.userId,
    required this.activityType,
    required this.inquiry,
    required this.date,
    required this.time,
    required this.isPrivate,
    DateTime? createdAt,
    List<String>? likedBy,
    List<String>? joinedBy,
    this.attendeeLimit,
    this.isInvited = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       likedBy = likedBy ?? [],
       joinedBy = joinedBy ?? [];

  // Convert TimeOfDay to a format that can be stored in Firestore
  Map<String, int> _timeOfDayToMap(TimeOfDay time) {
    return {
      'hour': time.hour,
      'minute': time.minute,
    };
  }

  // Convert from Firestore to TimeOfDay
  static TimeOfDay _mapToTimeOfDay(Map<String, dynamic> map) {
    return TimeOfDay(
      hour: map['hour'] as int,
      minute: map['minute'] as int,
    );
  }

  // Convert to a map for Firestore
  Map<String, dynamic> toMap() {
    final map = {
      'userId': userId,
      'activityType': activityType,
      'inquiry': inquiry,
      'date': Timestamp.fromDate(date),
      'time': _timeOfDayToMap(time),
      'isPrivate': isPrivate,
      'createdAt': Timestamp.fromDate(createdAt),
      'likedBy': likedBy,
      'joinedBy': joinedBy,
    };

    // Only add attendeeLimit if it's not null
    if (attendeeLimit != null) {
      map['attendeeLimit'] = attendeeLimit as int;
    }

    return map;
  }

  // Create an EventModel from a Firestore document
  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Timestamp timestamp = data['date'] as Timestamp;
    final Map<String, dynamic> timeMap = data['time'] as Map<String, dynamic>;
    final Timestamp createdTimestamp = data['createdAt'] as Timestamp;

    // Handle likedBy and joinedBy fields which might not exist in older documents
    List<String> likedBy = [];
    if (data['likedBy'] != null) {
      likedBy = List<String>.from(data['likedBy']);
    }

    List<String> joinedBy = [];
    if (data['joinedBy'] != null) {
      joinedBy = List<String>.from(data['joinedBy']);
    }

    // Handle attendeeLimit which might not exist in older documents
    int? attendeeLimit;
    if (data['attendeeLimit'] != null) {
      attendeeLimit = data['attendeeLimit'] as int;
    }

    // The isInvited property is not stored in Firestore
    // It's set programmatically when events are fetched from RSVPs
    // Default is false

    return EventModel(
      id: doc.id,
      userId: data['userId'] as String,
      activityType: data['activityType'] as String,
      inquiry: data['inquiry'] as String,
      date: timestamp.toDate(),
      time: _mapToTimeOfDay(timeMap),
      isPrivate: data['isPrivate'] as bool,
      createdAt: createdTimestamp.toDate(),
      likedBy: likedBy,
      joinedBy: joinedBy,
      attendeeLimit: attendeeLimit,
      isInvited: false, // Default to false, will be set to true for invited events
    );
  }

  // Create a copy of the event with updated fields
  EventModel copyWith({
    String? id,
    String? userId,
    String? activityType,
    String? inquiry,
    DateTime? date,
    TimeOfDay? time,
    bool? isPrivate,
    DateTime? createdAt,
    List<String>? likedBy,
    List<String>? joinedBy,
    int? attendeeLimit,
    bool? isInvited,
  }) {
    return EventModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      activityType: activityType ?? this.activityType,
      inquiry: inquiry ?? this.inquiry,
      date: date ?? this.date,
      time: time ?? this.time,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      likedBy: likedBy ?? this.likedBy,
      joinedBy: joinedBy ?? this.joinedBy,
      attendeeLimit: attendeeLimit ?? this.attendeeLimit,
      isInvited: isInvited ?? this.isInvited,
    );
  }

  // Override equals to properly identify duplicate events
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    if (other is! EventModel) return false;

    // Two events are considered equal if they have the same ID
    // OR if they have the same content (same user, inquiry, date, time)
    return id == other.id ||
           (userId == other.userId &&
            inquiry == other.inquiry &&
            _isSameDate(date, other.date) &&
            _isSameTime(time, other.time));
  }

  // Helper method to compare dates (ignoring time component)
  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Helper method to compare TimeOfDay
  bool _isSameTime(TimeOfDay a, TimeOfDay b) {
    return a.hour == b.hour && a.minute == b.minute;
  }

  // Override hashCode to be consistent with equals
  @override
  int get hashCode {
    // Use a combination of userId, inquiry, date and time for the hash
    return Object.hash(
      userId,
      inquiry,
      Object.hash(date.year, date.month, date.day),
      Object.hash(time.hour, time.minute)
    );
  }

  // Generate a unique content key for this event
  String get contentKey => '$userId-$inquiry-${date.year}-${date.month}-${date.day}-${time.hour}-${time.minute}';
}
