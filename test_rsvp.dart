import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/push_notification_service.dart';
import 'lib/services/rsvp_service.dart';
import 'lib/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize services
  final pushNotificationService = PushNotificationService();
  final rsvpService = RSVPService(pushNotificationService);
  
  // Get current user ID
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) {
    Logger.e('TestRSVP', 'User not authenticated');
    return;
  }
  
  Logger.d('TestRSVP', 'Current user ID: $currentUserId');
  
  // Check for RSVPs
  final rsvps = await rsvpService.getRSVPs().first;
  Logger.d('TestRSVP', 'Found ${rsvps.length} RSVPs');
  
  for (final rsvp in rsvps) {
    Logger.d('TestRSVP', 'RSVP: id=${rsvp.id}, eventId=${rsvp.eventId}, status=${rsvp.status}, inviterId=${rsvp.inviterId}, inviteeId=${rsvp.inviteeId}');
  }
  
  // Check for events in Firestore
  final firestore = FirebaseFirestore.instance;
  final eventsQuery = await firestore.collection('events').where('isPrivate', isEqualTo: true).get();
  Logger.d('TestRSVP', 'Found ${eventsQuery.docs.length} private events');
  
  for (final doc in eventsQuery.docs) {
    final data = doc.data();
    Logger.d('TestRSVP', 'Event: id=${doc.id}, inquiry=${data['inquiry']}, isPrivate=${data['isPrivate']}');
  }
  
  // Check for RSVPs in Firestore
  final rsvpQuery = await firestore.collection('rsvp').get();
  Logger.d('TestRSVP', 'Found ${rsvpQuery.docs.length} RSVPs in Firestore');
  
  for (final doc in rsvpQuery.docs) {
    final data = doc.data();
    Logger.d('TestRSVP', 'RSVP in Firestore: id=${doc.id}, eventId=${data['eventId']}, inviterId=${data['inviterId']}, inviteeId=${data['inviteeId']}, status=${data['status']}');
  }
}
