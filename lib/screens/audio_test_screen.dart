import 'package:flutter/material.dart';
import '../services/audio_analysis_test_service.dart';

class AudioTestScreen extends StatefulWidget {
  const AudioTestScreen({super.key});

  @override
  State<AudioTestScreen> createState() => _AudioTestScreenState();
}

class _AudioTestScreenState extends State<AudioTestScreen> {
  final AudioAnalysisTestService _testService = AudioAnalysisTestService();
  Map<String, dynamic>? _testResults;
  bool _isRunningTests = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Analysis Tests'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Analysis Test Suite',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This test suite verifies the functionality of the enhanced audio analysis service, including pitch detection, tempo analysis, real-time processing, and Indian music features.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isRunningTests ? null : _runTests,
              child: _isRunningTests
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Running Tests...'),
                      ],
                    )
                  : const Text('Run Comprehensive Tests'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _testResults == null
                  ? const Center(
                      child: Text(
                        'Tap "Run Comprehensive Tests" to start testing',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : _buildTestResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResults() {
    if (_testResults == null) return const SizedBox();

    final overallStatus = _testResults!['overall_status'] as String;
    final isSuccess = overallStatus == 'SUCCESS';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall status card
          Card(
            color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : Icons.error,
                    color: isSuccess ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Overall Status: $overallStatus',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSuccess
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        if (_testResults!.containsKey('timestamp'))
                          Text(
                            'Completed: ${_testResults!['timestamp']}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Individual test results
          ...(_testResults!.entries
              .where((entry) => entry.value is Map<String, dynamic>)
              .map(
                (entry) => _buildTestCard(
                  entry.key,
                  entry.value as Map<String, dynamic>,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTestCard(String testName, Map<String, dynamic> testResult) {
    final status = testResult['status'] as String? ?? 'UNKNOWN';
    final isPassed = status == 'PASSED';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          isPassed ? Icons.check_circle_outline : Icons.error_outline,
          color: isPassed ? Colors.green : Colors.red,
        ),
        title: Text(
          _formatTestName(testName),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isPassed ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        subtitle: Text(
          'Status: $status',
          style: TextStyle(
            color: isPassed ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: testResult.entries
                  .where((entry) => entry.key != 'status')
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              '${_formatKey(entry.key)}:',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _formatValue(entry.value),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTestName(String testName) {
    return testName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value is double) {
      return value.toStringAsFixed(2);
    } else if (value is List) {
      return value.length > 5
          ? '${value.take(5).join(', ')}... (${value.length} items)'
          : value.join(', ');
    } else if (value is bool) {
      return value ? '✅ Yes' : '❌ No';
    }
    return value.toString();
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunningTests = true;
      _testResults = null;
    });

    try {
      final results = await _testService.runComprehensiveTests();

      if (mounted) {
        setState(() {
          _testResults = results;
          _isRunningTests = false;
        });
      }

      // Print results to console for debugging
      _testService.printTestResults(results);

      // Show completion snackbar
      if (mounted) {
        final isSuccess = results['overall_status'] == 'SUCCESS';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSuccess
                  ? '✅ All tests completed successfully!'
                  : '❌ Some tests failed. Check results for details.',
            ),
            backgroundColor: isSuccess ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResults = {
            'overall_status': 'ERROR',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          };
          _isRunningTests = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Test execution failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _testService.dispose();
    super.dispose();
  }
}
