import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/retry_service.dart';
import '../../utils/logger.dart';

class RetryTestScreen extends ConsumerStatefulWidget {
  const RetryTestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<RetryTestScreen> createState() => _RetryTestScreenState();
}

class _RetryTestScreenState extends ConsumerState<RetryTestScreen> {
  final TextEditingController _successRateController = TextEditingController(text: '50');
  final TextEditingController _delayController = TextEditingController(text: '500');
  final TextEditingController _retriesController = TextEditingController(text: '3');
  String _resultText = '';
  bool _isLoading = false;
  final List<String> _logMessages = [];
  final Random _random = Random();

  @override
  void dispose() {
    _successRateController.dispose();
    _delayController.dispose();
    _retriesController.dispose();
    super.dispose();
  }

  Future<void> _testSingleRetry() async {
    final successRate = int.tryParse(_successRateController.text) ?? 50;
    final maxRetries = int.tryParse(_retriesController.text) ?? 3;

    setState(() {
      _isLoading = true;
      _resultText = 'Testing single retry...';
      _logMessages.clear();
    });

    try {
      final retryService = ref.read(retryServiceProvider);

      final result = await retryService.executeWithRetry<String>(
        operation: () async {
          _addLogMessage('Attempting operation...');

          // Simulate network delay
          await Future.delayed(Duration(milliseconds: int.tryParse(_delayController.text) ?? 500));

          // Randomly succeed or fail based on success rate
          if (_random.nextInt(100) >= successRate) {
            _addLogMessage('Operation failed, will retry if attempts remain');
            throw Exception('Simulated network error');
          }

          _addLogMessage('Operation succeeded!');
          return 'Operation completed successfully after ${DateTime.now().toIso8601String()}';
        },
        maxRetries: maxRetries,
        initialDelay: const Duration(milliseconds: 200),
        shouldRetry: (e) => true, // Always retry
        operationName: 'testOperation',
      );

      _showResult('Success: $result');
    } catch (e) {
      _showResult('All retries failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testRetryWithFallback() async {
    final successRate = int.tryParse(_successRateController.text) ?? 50;
    final maxRetries = int.tryParse(_retriesController.text) ?? 3;

    setState(() {
      _isLoading = true;
      _resultText = 'Testing retry with fallback...';
      _logMessages.clear();
    });

    try {
      final retryService = ref.read(retryServiceProvider);

      final result = await retryService.executeWithRetryAndFallback<String>(
        operation: () async {
          _addLogMessage('Attempting operation with fallback...');

          // Simulate network delay
          await Future.delayed(Duration(milliseconds: int.tryParse(_delayController.text) ?? 500));

          // Randomly succeed or fail based on success rate
          if (_random.nextInt(100) >= successRate) {
            _addLogMessage('Operation failed, will retry if attempts remain');
            throw Exception('Simulated network error');
          }

          _addLogMessage('Operation succeeded!');
          return 'Operation completed successfully after ${DateTime.now().toIso8601String()}';
        },
        fallbackValue: 'Fallback value used at ${DateTime.now().toIso8601String()}',
        maxRetries: maxRetries,
        initialDelay: const Duration(milliseconds: 200),
        shouldRetry: (e) => true, // Always retry
        operationName: 'testOperationWithFallback',
      );

      _showResult('Result: $result');
    } catch (e) {
      _showResult('Unexpected error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testBatchRetry() async {
    final successRate = int.tryParse(_successRateController.text) ?? 50;
    final maxRetries = int.tryParse(_retriesController.text) ?? 3;
    const numOperations = 5; // Number of operations in the batch

    setState(() {
      _isLoading = true;
      _resultText = 'Testing batch retry...';
      _logMessages.clear();
    });

    try {
      final retryService = ref.read(retryServiceProvider);

      final operations = List.generate(numOperations, (index) {
        return () async {
          _addLogMessage('Attempting operation $index...');

          // Simulate network delay
          await Future.delayed(Duration(milliseconds: int.tryParse(_delayController.text) ?? 500));

          // Randomly succeed or fail based on success rate
          // Make the first operation always succeed for testing
          if (index != 0 && _random.nextInt(100) >= successRate) {
            _addLogMessage('Operation $index failed, will retry if attempts remain');
            throw Exception('Simulated network error for operation $index');
          }

          _addLogMessage('Operation $index succeeded!');
          return 'Operation $index completed successfully after ${DateTime.now().toIso8601String()}';
        };
      });

      final results = await retryService.executeBatchWithRetry<String>(
        operations: operations,
        maxRetries: maxRetries,
        initialDelay: const Duration(milliseconds: 200),
        shouldRetry: (e) => true, // Always retry
        operationName: 'batchOperation',
      );

      _showResult('Batch results: ${results.length} operations completed');
      for (int i = 0; i < results.length; i++) {
        _addLogMessage('Result $i: ${results[i] ?? "Failed"}');
      }
    } catch (e) {
      _showResult('Batch operation failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addLogMessage(String message) {
    Logger.d('RetryTestScreen', message);
    setState(() {
      _logMessages.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  void _showResult(String result) {
    Logger.d('RetryTestScreen', result);
    setState(() {
      _resultText = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retry Service Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _successRateController,
                    decoration: const InputDecoration(
                      labelText: 'Success Rate (%)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _delayController,
                    decoration: const InputDecoration(
                      labelText: 'Delay (ms)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _retriesController,
                    decoration: const InputDecoration(
                      labelText: 'Max Retries',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testSingleRetry,
                  child: const Text('Test Single Retry'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testRetryWithFallback,
                  child: const Text('Test With Fallback'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testBatchRetry,
                  child: const Text('Test Batch Retry'),
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
            const Text(
              'Operation Log:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120, // Fixed height for the log
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logMessages[index],
                      style: const TextStyle(
                        color: Colors.green,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Testing Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Set a low success rate (e.g., 20%) to test retry logic\n'
              '2. Increase the delay to simulate slow network\n'
              '3. Try different max retry values\n'
              '4. Test with fallback to see graceful degradation\n'
              '5. Test batch operations to see parallel retry handling',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
