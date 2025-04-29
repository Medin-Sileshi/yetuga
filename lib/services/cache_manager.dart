import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

// Provider for the CacheManager
final cacheManagerProvider = Provider<CacheManager>((ref) => CacheManager());

class CacheManager {
  // Cache priority levels
  static const int PRIORITY_HIGH = 3;   // Critical data, keep longest
  static const int PRIORITY_MEDIUM = 2; // Important data
  static const int PRIORITY_LOW = 1;    // Nice to have data
  
  // Cache expiration times
  static const Duration HIGH_EXPIRATION = Duration(days: 7);
  static const Duration MEDIUM_EXPIRATION = Duration(days: 2);
  static const Duration LOW_EXPIRATION = Duration(hours: 12);
  
  // Maximum cache sizes (in entries)
  static const int MAX_MEMORY_CACHE_SIZE = 100;
  static const int MAX_DISK_CACHE_SIZE = 500;
  
  // In-memory cache
  final Map<String, _CacheEntry> _memoryCache = {};
  
  // Initialize the cache manager
  Future<void> initialize() async {
    try {
      Logger.d('CacheManager', 'Initializing cache manager');
      
      // Open Hive box for persistent cache
      await Hive.openBox('cache_metadata');
      
      // Clean expired cache entries
      await cleanExpiredCache();
      
      Logger.d('CacheManager', 'Cache manager initialized');
    } catch (e) {
      Logger.e('CacheManager', 'Error initializing cache manager', e);
    }
  }
  
  // Store data in cache with priority
  Future<void> put(String key, dynamic data, {int priority = PRIORITY_MEDIUM, bool persistToDisk = true}) async {
    try {
      final now = DateTime.now();
      final expiration = _getExpirationTime(priority);
      
      // Create cache entry
      final entry = _CacheEntry(
        data: data,
        timestamp: now,
        expirationTime: now.add(expiration),
        priority: priority,
      );
      
      // Store in memory cache
      _memoryCache[key] = entry;
      
      // Store on disk if requested
      if (persistToDisk) {
        await _persistToDisk(key, entry);
      }
      
      // Enforce memory cache size limit
      _enforceMemoryCacheLimit();
      
      Logger.d('CacheManager', 'Cached data for key: $key with priority: $priority');
    } catch (e) {
      Logger.e('CacheManager', 'Error caching data for key: $key', e);
    }
  }
  
  // Get data from cache
  Future<T?> get<T>(String key) async {
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(key)) {
        final entry = _memoryCache[key]!;
        
        // Check if expired
        if (DateTime.now().isBefore(entry.expirationTime)) {
          // Update access timestamp (LRU policy)
          entry.lastAccessed = DateTime.now();
          return entry.data as T?;
        } else {
          // Remove expired entry
          _memoryCache.remove(key);
        }
      }
      
      // Check disk cache
      final diskEntry = await _getFromDisk<T>(key);
      if (diskEntry != null) {
        // Add to memory cache
        _memoryCache[key] = diskEntry;
        return diskEntry.data as T?;
      }
      
      return null;
    } catch (e) {
      Logger.e('CacheManager', 'Error retrieving data for key: $key', e);
      return null;
    }
  }
  
  // Remove data from cache
  Future<void> remove(String key) async {
    try {
      // Remove from memory cache
      _memoryCache.remove(key);
      
      // Remove from disk cache
      final metadataBox = Hive.box('cache_metadata');
      await metadataBox.delete(key);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
      
      Logger.d('CacheManager', 'Removed cache entry for key: $key');
    } catch (e) {
      Logger.e('CacheManager', 'Error removing cache entry for key: $key', e);
    }
  }
  
  // Clear all cache
  Future<void> clearAll() async {
    try {
      // Clear memory cache
      _memoryCache.clear();
      
      // Clear disk cache
      final metadataBox = Hive.box('cache_metadata');
      final keys = metadataBox.keys.toList();
      
      final prefs = await SharedPreferences.getInstance();
      for (final key in keys) {
        await prefs.remove('cache_$key');
      }
      
      await metadataBox.clear();
      
      Logger.d('CacheManager', 'Cleared all cache');
    } catch (e) {
      Logger.e('CacheManager', 'Error clearing cache', e);
    }
  }
  
  // Clean expired cache entries
  Future<void> cleanExpiredCache() async {
    try {
      final now = DateTime.now();
      
      // Clean memory cache
      _memoryCache.removeWhere((key, entry) => now.isAfter(entry.expirationTime));
      
      // Clean disk cache
      final metadataBox = Hive.box('cache_metadata');
      final keys = metadataBox.keys.toList();
      final prefs = await SharedPreferences.getInstance();
      
      for (final key in keys) {
        final metadata = metadataBox.get(key);
        if (metadata != null) {
          final expirationTime = DateTime.parse(metadata['expirationTime']);
          if (now.isAfter(expirationTime)) {
            await metadataBox.delete(key);
            await prefs.remove('cache_$key');
          }
        }
      }
      
      Logger.d('CacheManager', 'Cleaned expired cache entries');
    } catch (e) {
      Logger.e('CacheManager', 'Error cleaning expired cache', e);
    }
  }
  
  // Get expiration time based on priority
  Duration _getExpirationTime(int priority) {
    switch (priority) {
      case PRIORITY_HIGH:
        return HIGH_EXPIRATION;
      case PRIORITY_MEDIUM:
        return MEDIUM_EXPIRATION;
      case PRIORITY_LOW:
        return LOW_EXPIRATION;
      default:
        return MEDIUM_EXPIRATION;
    }
  }
  
  // Persist cache entry to disk
  Future<void> _persistToDisk(String key, _CacheEntry entry) async {
    try {
      final metadataBox = Hive.box('cache_metadata');
      
      // Store metadata
      await metadataBox.put(key, {
        'timestamp': entry.timestamp.toIso8601String(),
        'expirationTime': entry.expirationTime.toIso8601String(),
        'priority': entry.priority,
        'lastAccessed': entry.lastAccessed.toIso8601String(),
      });
      
      // Store data
      final prefs = await SharedPreferences.getInstance();
      final jsonData = jsonEncode(entry.data);
      await prefs.setString('cache_$key', jsonData);
      
      // Enforce disk cache size limit
      await _enforceDiskCacheLimit();
    } catch (e) {
      Logger.e('CacheManager', 'Error persisting cache to disk for key: $key', e);
    }
  }
  
  // Get cache entry from disk
  Future<_CacheEntry?> _getFromDisk<T>(String key) async {
    try {
      final metadataBox = Hive.box('cache_metadata');
      final metadata = metadataBox.get(key);
      
      if (metadata == null) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString('cache_$key');
      
      if (jsonData == null) {
        return null;
      }
      
      final data = jsonDecode(jsonData);
      final timestamp = DateTime.parse(metadata['timestamp']);
      final expirationTime = DateTime.parse(metadata['expirationTime']);
      final priority = metadata['priority'] as int;
      final lastAccessed = DateTime.parse(metadata['lastAccessed']);
      
      // Check if expired
      if (DateTime.now().isAfter(expirationTime)) {
        await remove(key);
        return null;
      }
      
      // Update last accessed time
      final updatedMetadata = Map<String, dynamic>.from(metadata);
      updatedMetadata['lastAccessed'] = DateTime.now().toIso8601String();
      await metadataBox.put(key, updatedMetadata);
      
      return _CacheEntry(
        data: data,
        timestamp: timestamp,
        expirationTime: expirationTime,
        priority: priority,
        lastAccessed: DateTime.now(),
      );
    } catch (e) {
      Logger.e('CacheManager', 'Error retrieving cache from disk for key: $key', e);
      return null;
    }
  }
  
  // Enforce memory cache size limit (using LRU policy)
  void _enforceMemoryCacheLimit() {
    if (_memoryCache.length <= MAX_MEMORY_CACHE_SIZE) {
      return;
    }
    
    // Sort entries by priority (descending) and then by last accessed time (ascending)
    final entries = _memoryCache.entries.toList()
      ..sort((a, b) {
        // First compare by priority (higher priority = keep)
        final priorityComparison = b.value.priority.compareTo(a.value.priority);
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        
        // Then compare by last accessed time (older = remove)
        return a.value.lastAccessed.compareTo(b.value.lastAccessed);
      });
    
    // Remove oldest entries until we're under the limit
    final entriesToRemove = entries.length - MAX_MEMORY_CACHE_SIZE;
    for (var i = 0; i < entriesToRemove; i++) {
      _memoryCache.remove(entries[i].key);
    }
  }
  
  // Enforce disk cache size limit (using LRU policy)
  Future<void> _enforceDiskCacheLimit() async {
    try {
      final metadataBox = Hive.box('cache_metadata');
      
      if (metadataBox.length <= MAX_DISK_CACHE_SIZE) {
        return;
      }
      
      // Get all entries
      final entries = <Map<String, dynamic>>[];
      for (final key in metadataBox.keys) {
        final metadata = metadataBox.get(key);
        if (metadata != null) {
          entries.add({
            'key': key,
            'priority': metadata['priority'],
            'lastAccessed': DateTime.parse(metadata['lastAccessed']),
          });
        }
      }
      
      // Sort entries by priority (descending) and then by last accessed time (ascending)
      entries.sort((a, b) {
        // First compare by priority (higher priority = keep)
        final priorityComparison = b['priority'].compareTo(a['priority']);
        if (priorityComparison != 0) {
          return priorityComparison;
        }
        
        // Then compare by last accessed time (older = remove)
        return a['lastAccessed'].compareTo(b['lastAccessed']);
      });
      
      // Remove oldest entries until we're under the limit
      final entriesToRemove = entries.length - MAX_DISK_CACHE_SIZE;
      final prefs = await SharedPreferences.getInstance();
      
      for (var i = 0; i < entriesToRemove; i++) {
        final key = entries[i]['key'];
        await metadataBox.delete(key);
        await prefs.remove('cache_$key');
      }
    } catch (e) {
      Logger.e('CacheManager', 'Error enforcing disk cache limit', e);
    }
  }
}

// Cache entry class
class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final DateTime expirationTime;
  final int priority;
  DateTime lastAccessed;
  
  _CacheEntry({
    required this.data,
    required this.timestamp,
    required this.expirationTime,
    required this.priority,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? DateTime.now();
}
