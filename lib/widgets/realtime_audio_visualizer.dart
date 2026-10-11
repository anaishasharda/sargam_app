import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../services/realtime_audio_service.dart';
import '../services/indian_music_helper.dart';

class RealtimeAudioVisualizer extends StatefulWidget {
  final bool showIndianMusic;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;

  const RealtimeAudioVisualizer({
    super.key,
    this.showIndianMusic = true,
    this.onStartRecording,
    this.onStopRecording,
  });

  @override
  State<RealtimeAudioVisualizer> createState() =>
      _RealtimeAudioVisualizerState();
}

class _RealtimeAudioVisualizerState extends State<RealtimeAudioVisualizer>
    with TickerProviderStateMixin {
  final RealtimeAudioService _audioService = RealtimeAudioService();

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Current data
  RealtimeAudioData? _currentData;
  List<double> _waveformData = [];
  List<double> _spectrumData = [];

  // Historical data for graphs
  final List<FlSpot> _pitchHistory = [];
  final List<FlSpot> _volumeHistory = [];
  final List<FlSpot> _tempoHistory = [];
  final List<FlSpot> _qualityHistory = [];

  // State
  bool _isRecording = false;
  double _maxPitch = 1000.0;
  double _maxVolume = 1.0;
  double _maxTempo = 200.0;
  int _dataPointIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAudioService();
  }

  void _initializeControllers() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  Future<void> _initializeAudioService() async {
    try {
      await _audioService.initialize();

      // Listen to audio data stream
      _audioService.dataStream.listen(_onAudioData);
      _audioService.waveformStream.listen(_onWaveformData);
      _audioService.spectrumStream.listen(_onSpectrumData);
    } catch (e) {
      debugPrint('Error initializing audio service: $e');
      _showError('Failed to initialize audio service: $e');
    }
  }

  void _onAudioData(RealtimeAudioData data) {
    if (!mounted) return;

    setState(() {
      _currentData = data;
      _addToHistory(data);
    });
  }

  void _onWaveformData(List<double> waveform) {
    if (!mounted) return;

    setState(() {
      _waveformData = waveform;
    });
  }

  void _onSpectrumData(List<double> spectrum) {
    if (!mounted) return;

    setState(() {
      _spectrumData = spectrum;
    });
  }

  void _addToHistory(RealtimeAudioData data) {
    const maxHistoryPoints = 50;
    final x = _dataPointIndex.toDouble();

    // Add new data points
    _pitchHistory.add(FlSpot(x, data.pitch));
    _volumeHistory.add(FlSpot(x, data.volume * 100));
    _tempoHistory.add(FlSpot(x, data.tempo));
    _qualityHistory.add(FlSpot(x, data.quality));

    // Update max values for scaling
    _maxPitch = math.max(_maxPitch, data.pitch);
    _maxVolume = math.max(_maxVolume, data.volume);
    _maxTempo = math.max(_maxTempo, data.tempo);

    // Trim history
    if (_pitchHistory.length > maxHistoryPoints) {
      _pitchHistory.removeAt(0);
      _volumeHistory.removeAt(0);
      _tempoHistory.removeAt(0);
      _qualityHistory.removeAt(0);
    }

    _dataPointIndex++;
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        await _audioService.stopRealTimeAnalysis();
        _pulseController.stop();
        widget.onStopRecording?.call();
      } else {
        await _audioService.startRealTimeAnalysis();
        _pulseController.repeat(reverse: true);
        widget.onStartRecording?.call();
      }

      setState(() {
        _isRecording = !_isRecording;
      });
    } catch (e) {
      debugPrint('Error toggling recording: $e');
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControlPanel(),
        const SizedBox(height: 16),
        Expanded(
          child: _isRecording
              ? _buildVisualizationGrid()
              : _buildWelcomeScreen(),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _isRecording
                        ? [
                            BoxShadow(
                              color: Colors.red.withValues(
                                alpha: 0.3 * _pulseController.value,
                              ),
                              blurRadius: 20 * _pulseController.value,
                              spreadRadius: 10 * _pulseController.value,
                            ),
                          ]
                        : null,
                  ),
                  child: FloatingActionButton(
                    onPressed: _toggleRecording,
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    child: Icon(_isRecording ? Icons.stop : Icons.mic),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording ? 'Recording...' : 'Tap to start recording',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _isRecording ? Colors.red : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentData != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pitch: ${_currentData!.pitch.toStringAsFixed(1)} Hz | '
                      'Volume: ${(_currentData!.volume * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Real-Time Audio Analysis',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording to see live pitch, tempo, volume,\nnotes, quality, and brightness analysis',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizationGrid() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      padding: const EdgeInsets.all(8),
      children: [
        _buildWaveformCard(),
        _buildSpectrumCard(),
        _buildPitchCard(),
        _buildVolumeCard(),
        _buildTempoCard(),
        _buildQualityCard(),
        if (widget.showIndianMusic) ...[_buildNotesCard(), _buildRagaCard()],
      ],
    );
  }

  Widget _buildWaveformCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waveform',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _waveformData.isEmpty
                  ? const Center(child: Text('No data'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _waveformData
                                .toList()
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: false,
                            color: Colors.blue,
                            barWidth: 1,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        minX: 0,
                        maxX: _waveformData.length.toDouble(),
                        minY: -1,
                        maxY: 1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpectrumCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Frequency Spectrum',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _spectrumData.isEmpty
                  ? const Center(child: Text('No data'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _spectrumData.isNotEmpty
                            ? _spectrumData.reduce(math.max) * 1.1
                            : 1.0,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: _spectrumData
                            .take(20) // Show first 20 frequency bins
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (e) => BarChartGroupData(
                                x: e.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: e.value,
                                    color: Colors.purple,
                                    width: 3,
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPitchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pitch',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentData != null) ...[
              Text(
                '${_currentData!.pitch.toStringAsFixed(1)} Hz',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _pitchHistory.isEmpty
                  ? const Center(child: Text('No data'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _pitchHistory,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        minY: 0,
                        maxY: _maxPitch,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Volume',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentData != null) ...[
              Text(
                '${(_currentData!.volume * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _volumeHistory.isEmpty
                  ? const Center(child: Text('No data'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _volumeHistory,
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        minY: 0,
                        maxY: 100,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTempoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tempo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentData != null) ...[
              Text(
                '${_currentData!.tempo.toStringAsFixed(1)} BPM',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _tempoHistory.isEmpty
                  ? const Center(child: Text('No data'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _tempoHistory,
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        minY: 0,
                        maxY: _maxTempo,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality & Brightness',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentData != null) ...[
              Text(
                'Quality: ${_currentData!.quality.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Brightness: ${(_currentData!.brightness / 1000).toStringAsFixed(1)}k Hz',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _qualityHistory.isEmpty
                  ? const Center(child: Text('No data'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _qualityHistory,
                            isCurved: true,
                            color: Colors.teal,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        minY: 0,
                        maxY: 100,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detected Notes',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _currentData == null || _currentData!.notes.isEmpty
                  ? const Center(child: Text('No notes detected'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Western: ${_currentData!.notes.join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sargam: ${_currentData!.sargamNotes.join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.indigo,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: _currentData!.sargamNotes
                                .map(
                                  (note) => Chip(
                                    label: Text(
                                      note,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.indigo.shade100,
                                    side: BorderSide.none,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRagaCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raga Analysis',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _currentData == null
                  ? const Center(child: Text('No data'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentData!.identifiedRaga.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _currentData!.identifiedRaga,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_currentData!.tempo > 0) ...[
                          Text(
                            'Tempo: ${IndianMusicHelper.classifyTempo(_currentData!.tempo)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const Spacer(),
                        if (_currentData!.identifiedRaga.isNotEmpty) ...[
                          Text(
                            'Tap for practice tips',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
