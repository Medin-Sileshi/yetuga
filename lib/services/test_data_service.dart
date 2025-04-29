import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';

final testDataServiceProvider = Provider<TestDataService>((ref) {
  return TestDataService();
});

class TestDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String get _currentUserId => _auth.currentUser?.uid ?? '';

  // Collection reference
  CollectionReference get _eventsCollection => _firestore.collection('events');

  // Create test events
  Future<void> createTestEvents() async {
    try {
      Logger.d('TestDataService', 'Creating test events...');

      // Ensure we have a user ID
      if (_currentUserId.isEmpty) {
        Logger.e('TestDataService', 'User not authenticated');
        throw Exception('User not authenticated');
      }

      // Check if we already have events
      final querySnapshot = await _eventsCollection.limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        Logger.d('TestDataService', 'Events already exist, skipping test data creation');
        return;
      }

      // Create test events
      final testEvents = [
        EventModel(
          userId: _currentUserId,
          activityType: 'Hiking',
          inquiry: 'Mountain hike this weekend',
          date: DateTime.now().add(const Duration(days: 2)),
          time: const TimeOfDay(hour: 9, minute: 0),
          isPrivate: false,
          createdAt: DateTime.now(),
          likedBy: [],
          joinedBy: [_currentUserId],
        ),
        EventModel(
          userId: _currentUserId,
          activityType: 'Dinner',
          inquiry: 'Italian dinner party',
          date: DateTime.now().add(const Duration(days: 3)),
          time: const TimeOfDay(hour: 19, minute: 30),
          isPrivate: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          likedBy: [],
          joinedBy: [],
        ),
        EventModel(
          userId: _currentUserId,
          activityType: 'Movie',
          inquiry: 'Movie night at my place',
          date: DateTime.now().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 20, minute: 0),
          isPrivate: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          likedBy: [],
          joinedBy: [_currentUserId],
        ),
      ];

      // Add events to Firestore
      for (final event in testEvents) {
        await _eventsCollection.add(event.toMap());
      }

      Logger.d('TestDataService', 'Test events created successfully');
    } catch (e) {
      Logger.e('TestDataService', 'Error creating test events', e);
      rethrow;
    }
  }
}
