import 'package:flutter/material.dart';
import '../screens/realtime_analysis_screen.dart';
import '../services/realtime_audio_service.dart';

class TestRealtimeScreen extends StatefulWidget {
  const TestRealtimeScreen({super.key});

  @override
  State<TestRealtimeScreen> createState() => _TestRealtimeScreenState();
}

class _TestRealtimeScreenState extends State<TestRealtimeScreen> {
  final RealtimeAudioService _audioService = RealtimeAudioService();
  bool _isInitialized = false;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _audioService.initialize();
      setState(() {
        _isInitialized = true;
        _status = 'Service initialized successfully!';
      });
    } catch (e) {
      setState(() {
        _isInitialized = false;
        _status = 'Initialization failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Audio Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isInitialized ? Icons.check_circle : Icons.error,
              size: 80,
              color: _isInitialized ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 32),
            if (_isInitialized) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RealtimeAnalysisScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Real-Time Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Features included:\n'
                '• Live pitch detection\n'
                '• Real-time volume monitoring\n'
                '• Tempo analysis from rhythm\n'
                '• Audio quality assessment\n'
                '• Brightness (spectral centroid)\n'
                '• Musical note detection\n'
                '• Indian music (Sargam) support\n'
                '• Raga identification\n'
                '• Real-time graphs and visualization',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _initializeService,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Initialization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}

