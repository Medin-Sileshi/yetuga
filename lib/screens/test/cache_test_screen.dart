import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/cache_manager.dart';
import '../../utils/logger.dart';

class CacheTestScreen extends ConsumerStatefulWidget {
  const CacheTestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CacheTestScreen> createState() => _CacheTestScreenState();
}

class _CacheTestScreenState extends ConsumerState<CacheTestScreen> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  String _resultText = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _storeInCache() async {
    if (_keyController.text.isEmpty || _valueController.text.isEmpty) {
      _showResult('Please enter both key and value');
      return;
    }

    setState(() {
      _isLoading = true;
      _resultText = 'Storing data...';
    });

    try {
      final cacheManager = ref.read(cacheManagerProvider);
      await cacheManager.put(
        _keyController.text,
        _valueController.text,
        priority: CacheManager.priorityHigh,
      );
      _showResult('Data stored successfully with key: ${_keyController.text}');
    } catch (e) {
      _showResult('Error storing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _retrieveFromCache() async {
    if (_keyController.text.isEmpty) {
      _showResult('Please enter a key to retrieve');
      return;
    }

    setState(() {
      _isLoading = true;
      _resultText = 'Retrieving data...';
    });

    try {
      final cacheManager = ref.read(cacheManagerProvider);
      final value = await cacheManager.get<String>(_keyController.text);

      if (value != null) {
        _showResult('Retrieved value: $value');
        _valueController.text = value;
      } else {
        _showResult('No data found for key: ${_keyController.text}');
      }
    } catch (e) {
      _showResult('Error retrieving data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromCache() async {
    if (_keyController.text.isEmpty) {
      _showResult('Please enter a key to remove');
      return;
    }

    setState(() {
      _isLoading = true;
      _resultText = 'Removing data...';
    });

    try {
      final cacheManager = ref.read(cacheManagerProvider);
      await cacheManager.remove(_keyController.text);
      _showResult('Data removed for key: ${_keyController.text}');
      _valueController.clear();
    } catch (e) {
      _showResult('Error removing data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() {
      _isLoading = true;
      _resultText = 'Clearing cache...';
    });

    try {
      final cacheManager = ref.read(cacheManagerProvider);
      await cacheManager.clearAll();
      _showResult('Cache cleared successfully');
      _keyController.clear();
      _valueController.clear();
    } catch (e) {
      _showResult('Error clearing cache: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResult(String result) {
    Logger.d('CacheTestScreen', result);
    setState(() {
      _resultText = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Manager Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Cache Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Cache Value',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _storeInCache,
                  child: const Text('Store'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _retrieveFromCache,
                  child: const Text('Retrieve'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _removeFromCache,
                  child: const Text('Remove'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _clearCache,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear All'),
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
            const SizedBox(height: 24),
            const Text(
              'Testing Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Enter a key and value, then press "Store"\n'
              '2. Clear the fields and enter the same key, then press "Retrieve"\n'
              '3. Try removing the key with "Remove"\n'
              '4. Store multiple key-value pairs and test "Clear All"\n'
              '5. Close and reopen the app to test persistence',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
