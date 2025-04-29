import 'package:flutter/material.dart';
import 'cache_test_screen.dart';
import 'prefetch_test_screen.dart';
import 'retry_test_screen.dart';

class TestMenuScreen extends StatelessWidget {
  const TestMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimization Tests'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test your optimization features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildTestButton(
              context,
              'Cache Manager Test',
              'Test storing, retrieving, and managing cached data',
              Icons.storage,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CacheTestScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _buildTestButton(
              context,
              'Prefetch Service Test',
              'Test tracking and prefetching frequently accessed content',
              Icons.download,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrefetchTestScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _buildTestButton(
              context,
              'Retry Service Test',
              'Test retry logic for handling network failures',
              Icons.refresh,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RetryTestScreen()),
              ),
            ),
            const Spacer(),
            const Text(
              'These test screens help you verify that your optimization features are working correctly. Each screen provides specific tests for different aspects of the system.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}
