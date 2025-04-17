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
    );
  }
}
