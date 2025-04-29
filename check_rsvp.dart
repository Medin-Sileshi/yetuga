import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RSVP Check'),
        ),
        body: const RSVPCheckScreen(),
      ),
    );
  }
}

class RSVPCheckScreen extends StatefulWidget {
  const RSVPCheckScreen({super.key});

  @override
  State<RSVPCheckScreen> createState() => _RSVPCheckScreenState();
}

class _RSVPCheckScreenState extends State<RSVPCheckScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _output = 'Checking...';
  
  @override
  void initState() {
    super.initState();
    _checkRSVPs();
  }
  
  Future<void> _checkRSVPs() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() {
          _output = 'User not authenticated';
        });
        return;
      }
      
      setState(() {
        _output = 'Current user ID: $currentUserId\n\n';
      });
      
      // Check for RSVPs in the rsvp collection
      final rsvpQuery = await _firestore.collection('rsvp').get();
      
      setState(() {
        _output += 'Found ${rsvpQuery.docs.length} RSVPs in the rsvp collection\n\n';
      });
      
      for (final doc in rsvpQuery.docs) {
        final data = doc.data();
        setState(() {
          _output += 'RSVP: id=${doc.id}, eventId=${data['eventId']}, inviterId=${data['inviterId']}, inviteeId=${data['inviteeId']}, status=${data['status']}\n\n';
        });
      }
      
      // Check for invitations in the event_invitations collection
      final invitationsQuery = await _firestore.collection('event_invitations').get();
      
      setState(() {
        _output += 'Found ${invitationsQuery.docs.length} invitations in the event_invitations collection\n\n';
      });
      
      for (final doc in invitationsQuery.docs) {
        final data = doc.data();
        setState(() {
          _output += 'Invitation: id=${doc.id}, eventId=${data['eventId']}, inviterId=${data['inviterId']}, inviteeId=${data['inviteeId']}, status=${data['status']}\n\n';
        });
      }
      
      // Check for private events
      final privateEventsQuery = await _firestore.collection('events').where('isPrivate', isEqualTo: true).get();
      
      setState(() {
        _output += 'Found ${privateEventsQuery.docs.length} private events\n\n';
      });
      
      for (final doc in privateEventsQuery.docs) {
        final data = doc.data();
        setState(() {
          _output += 'Private Event: id=${doc.id}, inquiry=${data['inquiry']}, userId=${data['userId']}, joinedBy=${data['joinedBy']}\n\n';
        });
      }
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(_output),
    );
  }
}
