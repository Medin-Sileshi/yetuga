import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/event_model.dart';
import '../utils/logger.dart';
import 'event_cache_service.dart';
import 'firestore_config_service.dart';

// Provider for the SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final eventCacheService = ref.read(eventCacheServiceProvider);
  final firestoreConfigService = ref.read(firestoreConfigServiceProvider);
  return SyncService(eventCacheService, firestoreConfigService);
});

class SyncService {
  final EventCacheService _eventCacheService;
  final FirestoreConfigService _firestoreConfigService;

  // Connectivity stream subscription
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Sync status
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Pending operations queue
  final List<Map<String, dynamic>> _pendingOperations = [];

  // Background sync timer
  Timer? _syncTimer;

  // Sync interval (default: 15 minutes)
  Duration _syncInterval = const Duration(minutes: 15);

  SyncService(this._eventCacheService, this._firestoreConfigService);

  // Initialize the sync service
  Future<void> initialize() async {
    try {
      Logger.d('SyncService', 'Initializing sync service');

      // Listen for connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

      // Start periodic sync
      _startPeriodicSync();

      Logger.d('SyncService', 'Sync service initialized');
    } catch (e) {
      Logger.e('SyncService', 'Error initializing sync service', e);
    }
  }

  // Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) async {
    Logger.d('SyncService', 'Connectivity changed: $result');

    if (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi) {
      // We're online, try to sync pending operations
      await syncPendingOperations();
    }
  }

  // Start periodic sync
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      await syncData();
    });
    Logger.d('SyncService', 'Periodic sync started with interval: $_syncInterval');
  }

  // Set sync interval
  void setSyncInterval(Duration interval) {
    _syncInterval = interval;
    _startPeriodicSync();
    Logger.d('SyncService', 'Sync interval updated: $_syncInterval');
  }

  // Sync data
  Future<void> syncData() async {
    if (_isSyncing) {
      Logger.d('SyncService', 'Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;

    try {
      Logger.d('SyncService', 'Starting data sync');

      // Check if we're online
      final isOnline = await _firestoreConfigService.isOnline();
      if (!isOnline) {
        Logger.d('SyncService', 'Device is offline, skipping sync');
        _isSyncing = false;
        return;
      }

      // Sync pending operations first
      await syncPendingOperations();

      // Sync user's events
      await _syncUserEvents();

      _lastSyncTime = DateTime.now();
      Logger.d('SyncService', 'Data sync completed');
    } catch (e) {
      Logger.e('SyncService', 'Error syncing data', e);
    } finally {
      _isSyncing = false;
    }
  }

  // Sync user's events
  Future<void> _syncUserEvents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Logger.d('SyncService', 'No user logged in, skipping event sync');
        return;
      }

      Logger.d('SyncService', 'Syncing events for user: ${user.uid}');

      // Get events created by the user
      final createdEventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      // Get events joined by the user
      final joinedEventsQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('joinedBy', arrayContains: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      // Combine and deduplicate events
      final allEvents = <EventModel>[];
      final eventIds = <String>{};

      for (final doc in createdEventsQuery.docs) {
        final event = EventModel.fromFirestore(doc);
        if (!eventIds.contains(event.id)) {
          allEvents.add(event);
          eventIds.add(event.id);
        }
      }

      for (final doc in joinedEventsQuery.docs) {
        final event = EventModel.fromFirestore(doc);
        if (!eventIds.contains(event.id)) {
          allEvents.add(event);
          eventIds.add(event.id);
        }
      }

      // Update the cache
      for (final event in allEvents) {
        _eventCacheService.updateEvent(event);
      }

      Logger.d('SyncService', 'Synced ${allEvents.length} events for user: ${user.uid}');
    } catch (e) {
      Logger.e('SyncService', 'Error syncing user events', e);
    }
  }

  // Add a pending operation
  void addPendingOperation(String collection, String operation, Map<String, dynamic> data) {
    _pendingOperations.add({
      'collection': collection,
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    Logger.d('SyncService', 'Added pending operation: $operation on $collection');

    // Try to sync immediately if possible
    syncPendingOperations();
  }

  // Sync pending operations
  Future<void> syncPendingOperations() async {
    if (_pendingOperations.isEmpty) {
      return;
    }

    try {
      Logger.d('SyncService', 'Syncing ${_pendingOperations.length} pending operations');

      // Check if we're online
      final isOnline = await _firestoreConfigService.isOnline();
      if (!isOnline) {
        Logger.d('SyncService', 'Device is offline, cannot sync pending operations');
        return;
      }

      // Process operations in order
      final operations = List<Map<String, dynamic>>.from(_pendingOperations);
      _pendingOperations.clear();

      for (final op in operations) {
        try {
          final collection = op['collection'] as String;
          final operation = op['operation'] as String;
          final data = op['data'] as Map<String, dynamic>;

          switch (operation) {
            case 'create':
              await FirebaseFirestore.instance.collection(collection).add(data);
              break;
            case 'update':
              final docId = data['id'];
              if (docId != null) {
                // Remove id from data before updating
                final updateData = Map<String, dynamic>.from(data);
                updateData.remove('id');
                await FirebaseFirestore.instance.collection(collection).doc(docId).update(updateData);
              }
              break;
            case 'delete':
              final docId = data['id'];
              if (docId != null) {
                await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
              }
              break;
          }

          Logger.d('SyncService', 'Successfully processed operation: $operation on $collection');
        } catch (e) {
          Logger.e('SyncService', 'Error processing operation', e);
          // Add back to pending operations
          _pendingOperations.add(op);
        }
      }

      Logger.d('SyncService', 'Pending operations sync completed, ${_pendingOperations.length} operations remaining');
    } catch (e) {
      Logger.e('SyncService', 'Error syncing pending operations', e);
    }
  }

  // Get sync status
  Map<String, dynamic> getSyncStatus() {
    return {
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'pendingOperations': _pendingOperations.length,
      'syncInterval': _syncInterval.inMinutes,
    };
  }

  // Force sync
  Future<void> forceSync() async {
    await syncData();
  }

  // Dispose
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    Logger.d('SyncService', 'Sync service disposed');
  }
}
