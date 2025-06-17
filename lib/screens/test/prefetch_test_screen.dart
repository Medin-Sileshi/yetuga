import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/prefetch_service.dart';
import '../../services/event_cache_service.dart';
import '../../utils/logger.dart';

class PrefetchTestScreen extends ConsumerStatefulWidget {
  const PrefetchTestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PrefetchTestScreen> createState() => _PrefetchTestScreenState();
}

class _PrefetchTestScreenState extends ConsumerState<PrefetchTestScreen> {
  final TextEditingController _eventIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  String _resultText = '';
  bool _isLoading = false;
  Map<String, dynamic> _prefetchStatus = {};

  @override
  void initState() {
    super.initState();
    _updatePrefetchStatus();
  }

  @override
  void dispose() {
    _eventIdController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _updatePrefetchStatus() async {
    final prefetchService = ref.read(prefetchServiceProvider);
    setState(() {
      _prefetchStatus = prefetchService.getPrefetchStatus();
    });
  }

  Future<void> _trackEventView() async {
    if (_eventIdController.text.isEmpty) {
      _showResult('Please enter an event ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _resultText = 'Tracking event view...';
    });

    try {
      final prefetchService = ref.read(prefetchServiceProvider);
      await prefetchService.trackEventView(_eventIdController.text);
      _showResult('Event view tracked for: ${_eventIdController.text}');
      await _updatePrefetchStatus();
    } catch (e) {
      _showResult('Error tracking event view: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _trackUserInteraction() async {
    if (_userIdController.text.isEmpty) {
      _showResult('Please enter a user ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _resultText = 'Tracking user interaction...';
    });

    try {
      final prefetchService = ref.read(prefetchServiceProvider);
      await prefetchService.trackUserInteraction(_userIdController.text);
      _showResult('User interaction tracked for: ${_userIdController.text}');
      await _updatePrefetchStatus();
    } catch (e) {
      _showResult('Error tracking user interaction: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forcePrefetch() async {
    setState(() {
      _isLoading = true;
      _resultText = 'Forcing prefetch...';
    });

    try {
      final prefetchService = ref.read(prefetchServiceProvider);
      await prefetchService.forcePrefetch();
      _showResult('Prefetch completed successfully');
      await _updatePrefetchStatus();
    } catch (e) {
      _showResult('Error during prefetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkCachedEvents() async {
    setState(() {
      _isLoading = true;
      _resultText = 'Checking cached events...';
    });

    try {
      final eventCacheService = ref.read(eventCacheServiceProvider);
      final cacheSize = eventCacheService.cacheSize;
      _showResult('Number of events in cache: $cacheSize');
    } catch (e) {
      _showResult('Error checking cached events: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResult(String result) {
    Logger.d('PrefetchTestScreen', result);
    setState(() {
      _resultText = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prefetch Service Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _eventIdController,
              decoration: const InputDecoration(
                labelText: 'Event ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _trackEventView,
              child: const Text('Track Event View'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _trackUserInteraction,
              child: const Text('Track User Interaction'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _forcePrefetch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Force Prefetch'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _checkCachedEvents,
                  child: const Text('Check Cached Events'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Text(
                      _resultText,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Prefetch Status:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text('Is Prefetching: ${_prefetchStatus['isPrefetching'] ?? 'N/A'}'),
                  Text('Last Prefetch: ${_prefetchStatus['lastPrefetchTime'] ?? 'Never'}'),
                  Text('Tracked Events: ${_prefetchStatus['trackedEvents'] ?? 0}'),
                  Text('Tracked Users: ${_prefetchStatus['trackedUsers'] ?? 0}'),
                  Text('Prefetch Interval: ${_prefetchStatus['prefetchInterval'] ?? 0} minutes'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Testing Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Enter an event ID and track it multiple times\n'
              '2. Enter a user ID and track interactions\n'
              '3. Force a prefetch to load popular content\n'
              '4. Check the cache to see if events were prefetched\n'
              '5. Close and reopen the app to test persistence',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
