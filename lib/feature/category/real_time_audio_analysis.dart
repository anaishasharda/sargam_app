// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../services/audio_analysis_service.dart';
import '../../models/audio_characteristics.dart';
import '../../models/audio_feedback.dart';

class RealTimeAudioAnalysis extends StatefulWidget {
  final String referenceAudioPath;
  final List<String> expectedNotes;
  final Function(AudioFeedback) onAnalysisComplete;
  final Function(AudioCharacteristics) onRealTimeUpdate;

  const RealTimeAudioAnalysis({
    super.key,
    required this.referenceAudioPath,
    required this.expectedNotes,
    required this.onAnalysisComplete,
    required this.onRealTimeUpdate,
  });

  @override
  State<RealTimeAudioAnalysis> createState() => _RealTimeAudioAnalysisState();
}

class _RealTimeAudioAnalysisState extends State<RealTimeAudioAnalysis>
    with TickerProviderStateMixin {
  final AudioAnalysisService _analysisService = AudioAnalysisService();

  StreamSubscription<AudioCharacteristics>? _analysisSubscription;
  AudioCharacteristics? _currentCharacteristics;
  AudioCharacteristics? _referenceCharacteristics;
  bool _isAnalyzing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<double> _userPitchHistory = [];
  Timer? _waveformTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadReferenceAudio();
  }

  @override
  void dispose() {
    _analysisSubscription?.cancel();
    _pulseController.dispose();
    _waveformTimer?.cancel();
    _analysisService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadReferenceAudio() async {
    try {
      _referenceCharacteristics = await _analysisService.analyzeAudioFile(
        widget.referenceAudioPath,
      );
      if (_referenceCharacteristics != null &&
          _isEmptyCharacteristics(_referenceCharacteristics!)) {
        throw Exception('Reference audio analysis returned empty data.');
      }
    } catch (e) {
      print('Error loading reference audio: $e');
      _referenceCharacteristics = AudioCharacteristics(
        pitch: 0.0,
        tempo: 0.0,
        rhythm: const [],
        notes: widget.expectedNotes,
        volume: 0.0,
        spectrum: const [],
        duration: 0.0,
      );
    }
  }

  void _startRealTimeAnalysis() async {
    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _userPitchHistory.clear();
    });

    try {
      // Use the new improved real-time analysis with recording
      final analysisStream = await _analysisService
          .startRealTimeAnalysisWithRecording();
      _analysisSubscription = analysisStream.listen(
        (characteristics) {
          setState(() {
            _currentCharacteristics = characteristics;
          });
          widget.onRealTimeUpdate(characteristics);
          _updatePitchHistory(characteristics);
        },
        onError: (error) {
          print('Real-time analysis error: $error');
          _stopRealTimeAnalysis();
        },
      );
    } catch (e) {
      print('Error starting real-time analysis: $e');
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _stopRealTimeAnalysis() async {
    if (!_isAnalyzing) return;

    _analysisSubscription?.cancel();
    await _analysisService.stopRealTimeAnalysisWithRecording();

    setState(() {
      _isAnalyzing = false;
    });

    // Perform final analysis if we have both reference and current characteristics
    if (_referenceCharacteristics != null && _currentCharacteristics != null) {
      try {
        final feedback = await _analysisService.compareAudio(
          _referenceCharacteristics!,
          _currentCharacteristics!,
          widget.expectedNotes,
        );
        widget.onAnalysisComplete(feedback);
      } catch (e) {
        print('Error comparing audio: $e');
      }
    }
  }

  void _updatePitchHistory(AudioCharacteristics characteristics) {
    setState(() {
      _userPitchHistory.add(characteristics.pitch);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurpleAccent.withValues(alpha: 0.1),
            Colors.purpleAccent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Real-Time Audio Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              _buildAnalysisButton(),
            ],
          ),

          const SizedBox(height: 20),

          // Real-time characteristics display
          if (_currentCharacteristics != null) _buildCharacteristicsDisplay(),

          const SizedBox(height: 20),

          // Pitch visualization
          if (_isAnalyzing) _buildPitchTrajectoryVisualization(),

          const SizedBox(height: 20),

          // Analysis status
          _buildAnalysisStatus(),
        ],
      ),
    );
  }

  Widget _buildAnalysisButton() {
    return GestureDetector(
      onTap: _isAnalyzing ? _stopRealTimeAnalysis : _startRealTimeAnalysis,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isAnalyzing ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isAnalyzing ? Colors.red : Colors.green,
                boxShadow: [
                  BoxShadow(
                    color: (_isAnalyzing ? Colors.red : Colors.green)
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _isAnalyzing ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCharacteristicsDisplay() {
    if (_currentCharacteristics == null) return const SizedBox.shrink();

    final characteristics = _currentCharacteristics!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Pitch and Tempo
          Row(
            children: [
              Expanded(
                child: _buildCharacteristicItem(
                  'Pitch',
                  '${characteristics.pitch.toStringAsFixed(1)} Hz',
                  Icons.trending_up,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCharacteristicItem(
                  'Tempo',
                  '${characteristics.tempo.toStringAsFixed(1)} BPM',
                  Icons.speed,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Volume and Notes
          Row(
            children: [
              Expanded(
                child: _buildCharacteristicItem(
                  'Volume',
                  '${(characteristics.volume * 100).toStringAsFixed(1)}%',
                  Icons.volume_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCharacteristicItem(
                  'Notes',
                  characteristics.notes.isNotEmpty
                      ? characteristics.notes.join(', ')
                      : 'None detected',
                  Icons.music_note,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quality indicators
          Row(
            children: [
              Expanded(
                child: _buildQualityIndicator(
                  'Quality',
                  characteristics.qualityScore,
                  Icons.star,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQualityIndicator(
                  'Brightness',
                  (characteristics.spectralCentroid / 1000).clamp(0.0, 100.0),
                  Icons.wb_sunny,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacteristicItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(String label, double value, IconData icon) {
    final color = _getQualityColor(value);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPitchTrajectoryVisualization() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: PitchTrajectoryPainter(
              _referenceCharacteristics?.pitchTrajectory ?? [],
              _userPitchHistory,
            ),
            size: Size.infinite,
          ),
          Positioned(
            bottom: 8,
            right: 12,
            child: Text(
              'Pitch Match',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isAnalyzing
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isAnalyzing ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isAnalyzing ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isAnalyzing ? 'Analyzing...' : 'Ready to analyze',
            style: TextStyle(
              color: _isAnalyzing ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(double value) {
    if (value >= 80) return Colors.green;
    if (value >= 60) return Colors.orange;
    return Colors.red;
  }

  bool _isEmptyCharacteristics(AudioCharacteristics characteristics) {
    return characteristics.pitch == 0.0 &&
        characteristics.tempo == 0.0 &&
        characteristics.notes.isEmpty &&
        characteristics.volume == 0.0 &&
        characteristics.spectrum.isEmpty;
  }
}

class PitchTrajectoryPainter extends CustomPainter {
  final List<double> referenceTrajectory;
  final List<double> userTrajectory;

  PitchTrajectoryPainter(this.referenceTrajectory, this.userTrajectory);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // A reasonable range for the human voice (e.g., 80Hz to 1000Hz)
    const double minPitch = 80.0;
    const double maxPitch = 1000.0;

    final refPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.4)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final userPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // We assume the total width represents the reference duration
    // If the reference is empty, we fake an expected length for scrolling
    int totalPoints = referenceTrajectory.isNotEmpty
        ? referenceTrajectory.length
        : math.max(100, userTrajectory.length);

    if (referenceTrajectory.isNotEmpty) {
      _drawTrajectory(
        canvas,
        referenceTrajectory,
        refPaint,
        width,
        height,
        minPitch,
        maxPitch,
        totalPoints,
      );
    }

    if (userTrajectory.isNotEmpty) {
      _drawTrajectory(
        canvas,
        userTrajectory,
        userPaint,
        width,
        height,
        minPitch,
        maxPitch,
        totalPoints,
      );
    }
  }

  void _drawTrajectory(
    Canvas canvas,
    List<double> trajectory,
    Paint paint,
    double width,
    double height,
    double minP,
    double maxP,
    int totalPoints,
  ) {
    final path = Path();
    bool isFirst = true;

    // Calculate log scale bounds
    final logMin = math.log(minP);
    final logMax = math.log(maxP);

    for (int i = 0; i < trajectory.length; i++) {
      final pitch = trajectory[i];
      if (pitch <= 0 || pitch.isNaN || pitch.isInfinite) {
        isFirst = true; // Break the line securely
        continue;
      }

      // Log scale better represents human perception of octaves
      final logPitch = math.log(pitch);
      final normalizedY = (logPitch - logMin) / (logMax - logMin);
      final clampedY = normalizedY.clamp(0.0, 1.0);

      final x = (i / totalPoints) * width;
      final y = height - (clampedY * height); // invert Y so higher pitch is up

      if (isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // We can also draw circles on the active notes
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PitchTrajectoryPainter oldDelegate) {
    return oldDelegate.userTrajectory.length != userTrajectory.length ||
        oldDelegate.referenceTrajectory.length != referenceTrajectory.length;
  }
}
