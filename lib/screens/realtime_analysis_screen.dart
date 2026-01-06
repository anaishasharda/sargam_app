import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/realtime_audio_visualizer.dart';
// import '../services/realtime_audio_service.dart'; // Not directly used in this file
import '../services/indian_music_helper.dart';

class RealtimeAnalysisScreen extends StatefulWidget {
  const RealtimeAnalysisScreen({super.key});

  @override
  State<RealtimeAnalysisScreen> createState() => _RealtimeAnalysisScreenState();
}

class _RealtimeAnalysisScreenState extends State<RealtimeAnalysisScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _hasPermissions = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final microphoneStatus = await Permission.microphone.request();

      if (microphoneStatus.isGranted) {
        setState(() {
          _hasPermissions = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasPermissions = false;
          _isLoading = false;
          _errorMessage =
              'Microphone permission is required for real-time analysis';
        });
      }
    } catch (e) {
      setState(() {
        _hasPermissions = false;
        _isLoading = false;
        _errorMessage = 'Error checking permissions: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Audio Analysis'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: _hasPermissions
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.graphic_eq), text: 'Analysis'),
                  Tab(icon: Icon(Icons.music_note), text: 'Indian Music'),
                  Tab(icon: Icon(Icons.help_outline), text: 'Help'),
                ],
              )
            : null,
        actions: [
          if (_hasPermissions)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _checkPermissions,
              tooltip: 'Refresh permissions',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking permissions...'),
          ],
        ),
      );
    }

    if (!_hasPermissions) {
      return _buildPermissionError();
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildAnalysisTab(), _buildIndianMusicTab(), _buildHelpTab()],
    );
  }

  Widget _buildPermissionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_off, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 24),
            Text(
              'Microphone Access Required',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ??
                  'Please grant microphone permission to use real-time audio analysis.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAppSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _checkPermissions,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTab() {
    return const RealtimeAudioVisualizer(showIndianMusic: false);
  }

  Widget _buildIndianMusicTab() {
    return const RealtimeAudioVisualizer(showIndianMusic: true);
  }

  Widget _buildHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpSection('Getting Started', [
            '1. Grant microphone permission when prompted',
            '2. Tap the microphone button to start recording',
            '3. Sing, play an instrument, or make sounds',
            '4. Watch real-time analysis of your audio',
            '5. Tap stop to end the session',
          ], Icons.play_arrow),
          _buildHelpSection('Understanding the Metrics', [
            'Pitch: The fundamental frequency in Hz',
            'Volume: Sound intensity as a percentage',
            'Tempo: Beats per minute (BPM) from rhythm',
            'Quality: Overall audio clarity score',
            'Brightness: Spectral centroid (tonal brightness)',
            'Notes: Detected musical notes (Western & Riti)',
          ], Icons.analytics),
          _buildHelpSection('Indian Classical Music Features', [
            'Riti Notes: Western notes converted to Indian solfege',
            'Raga Identification: Automatic raga detection',
            'Tempo Classification: Vilambit, Madhya, Drut, Ati Drut',
            'Practice Tips: Contextual suggestions for improvement',
          ], Icons.music_note),
          _buildHelpSection('Visualization Graphs', [
            'Waveform: Raw audio signal over time',
            'Spectrum: Frequency distribution (FFT)',
            'Pitch History: Pitch changes over time',
            'Volume History: Volume changes over time',
            'Tempo History: Rhythm analysis over time',
            'Quality History: Audio quality over time',
          ], Icons.show_chart),
          _buildHelpSection('Tips for Best Results', [
            '• Use in a quiet environment',
            '• Hold device steady during recording',
            '• Speak/sing clearly and at normal volume',
            '• For Indian music: use tanpura for reference pitch',
            '• Practice scales and arpeggios for better analysis',
          ], Icons.tips_and_updates),
          _buildHelpSection('Common Ragas Supported', [
            'Bilawal, Kafi, Bhairav, Kalyan, Khamaj',
            'Asavari, Bhairavi, Marwa, Poorvi, Todi',
            'More ragas will be added in future updates',
          ], Icons.library_music),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<String> items, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.startsWith('•') ? '' : '• ',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Expanded(
                      child: Text(
                        item.startsWith('•') ? item.substring(2) : item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

/// Extension to show practice suggestions for a raga
extension RagaPracticeDialog on State<RealtimeAnalysisScreen> {
  void showRagaPracticeDialog(String raga) {
    if (!mounted) return;

    final suggestions = IndianMusicHelper.getRagaPracticeSuggestions(raga);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Practice Tips for $raga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: suggestions
              .map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(suggestion)),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
