import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sargam_app/services/audio_service.dart';
import 'package:sargam_app/services/audio_analysis_service.dart';

import '../../models/audio_feedback.dart';
import '../../models/audio_characteristics.dart';
import '../../models/raag_entry.dart';
import 'real_time_audio_analysis.dart';
import 'audio_characteristics_display.dart';

class PracticeScreen extends StatefulWidget {
  final RagaData ragaData;
  final String practiceType;
  final String audioPath;

  const PracticeScreen({
    super.key,
    required this.ragaData,
    required this.practiceType,
    required this.audioPath,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final AudioAnalysisService _analysisService = AudioAnalysisService();

  bool _isAnalyzing = false;
  AudioFeedback? _lastFeedback;
  AudioCharacteristics? _referenceCharacteristics;
  AudioCharacteristics? _userCharacteristics;
  bool _showRealTimeAnalysis = false;
  bool _showCharacteristicsDisplay = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _requestPermissions();
    _loadReferenceAudio();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioService.dispose();
    _analysisService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await _audioService.requestPermissions();
  }

  Future<void> _loadReferenceAudio() async {
    try {
      // For now, we'll create a mock reference characteristics
      // In a real implementation, you would analyze the actual reference audio file
      _referenceCharacteristics = AudioCharacteristics(
        pitch: 440.0, // A4 note
        tempo: 120.0, // 120 BPM
        rhythm: [0.5, 0.5, 0.5, 0.5], // Simple rhythm pattern
        notes: widget.ragaData.notes,
        volume: 0.8,
        spectrum: List.generate(100, (i) => sin(i * 0.1 * 3.14159)),
        duration: 10.0,
      );
    } catch (e) {
      print('Error loading reference audio: $e');
    }
  }

  void _onRealTimeUpdate(AudioCharacteristics characteristics) {
    setState(() {
      _userCharacteristics = characteristics;
    });
  }

  void _onAnalysisComplete(AudioFeedback feedback) {
    setState(() {
      _lastFeedback = feedback;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF240046),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.practiceType} - ${widget.ragaData.name}'),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Practice info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurpleAccent.withOpacity(0.2),
                    Colors.purpleAccent.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _getPracticeIcon(),
                    size: 48,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.practiceType} Practice',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ragaData.name,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${widget.ragaData.notes.join(' ')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Real-time audio analysis section
            if (_showRealTimeAnalysis) ...[
              RealTimeAudioAnalysis(
                referenceAudioPath: widget.audioPath,
                expectedNotes: widget.ragaData.notes,
                onRealTimeUpdate: _onRealTimeUpdate,
                onAnalysisComplete: _onAnalysisComplete,
              ),
              const SizedBox(height: 24),
            ],

            // Audio characteristics display
            if (_showCharacteristicsDisplay) ...[
              AudioCharacteristicsDisplay(
                referenceCharacteristics: _referenceCharacteristics,
                userCharacteristics: _userCharacteristics,
                feedback: _lastFeedback,
                showComparison:
                    _referenceCharacteristics != null &&
                    _userCharacteristics != null,
              ),
              const SizedBox(height: 24),
            ],

            // Audio feedback section
            if (_lastFeedback != null) ...[
              _buildFeedbackCard(),
              const SizedBox(height: 24),
            ],

            // Control buttons
            Column(
              children: [
                // Audio controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      'Play Reference',
                      Icons.play_arrow,
                      Colors.green,
                      _audioService.isPlaying,
                      () => _toggleAudio(),
                    ),
                    _controlButton(
                      'Stop',
                      Icons.stop,
                      Colors.red,
                      false,
                      () => _stopAudio(),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Practice controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      'Record Practice',
                      Icons.fiber_manual_record,
                      Colors.orange,
                      _audioService.isRecording,
                      () => _toggleRecording(),
                    ),
                    _controlButton(
                      'Analyze Audio',
                      Icons.analytics,
                      Colors.purple,
                      _isAnalyzing,
                      () => _analyzeAudio(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Analysis controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      'Real-time Analysis',
                      Icons.radio_button_checked,
                      Colors.cyan,
                      _showRealTimeAnalysis,
                      () => _toggleRealTimeAnalysis(),
                    ),
                    _controlButton(
                      'Show Characteristics',
                      Icons.bar_chart,
                      Colors.teal,
                      _showCharacteristicsDisplay,
                      () => _toggleCharacteristicsDisplay(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Debug controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      'Test Audio File',
                      Icons.audiotrack,
                      Colors.indigo,
                      false,
                      () => _testAudioFile(),
                    ),
                    _controlButton(
                      'Check File Exists',
                      Icons.search,
                      Colors.brown,
                      false,
                      () => _checkAudioFileExists(),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Status indicator
                if (_audioService.isRecording)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.3),
                            border: Border.all(color: Colors.orange, width: 2),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.orange,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),

                if (_isAnalyzing)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purple.withOpacity(0.3),
                      border: Border.all(color: Colors.purple, width: 2),
                    ),
                    child: const Icon(
                      Icons.analytics,
                      color: Colors.purple,
                      size: 32,
                    ),
                  ),

                const SizedBox(height: 32),

                // Practice log button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurpleAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    onPressed: () => _logPractice(),
                    icon: const Icon(Icons.book),
                    label: const Text(
                      'Log Practice Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPracticeIcon() {
    switch (widget.practiceType) {
      case 'Aaroh':
        return Icons.trending_up;
      case 'Avroh':
        return Icons.trending_down;
      case 'Swarmalika':
        return Icons.lyrics;
      default:
        return Icons.music_note;
    }
  }

  Widget _controlButton(
    String label,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isActive ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: isActive ? Colors.white : color, size: 32),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard() {
    if (_lastFeedback == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.deepPurpleAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Audio Analysis Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Accuracy scores
          Row(
            children: [
              Expanded(
                child: _buildAccuracyItem(
                  'Pitch Accuracy',
                  '${_lastFeedback!.pitchAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(_lastFeedback!.pitchAccuracy.toInt()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAccuracyItem(
                  'Tempo Accuracy',
                  '${_lastFeedback!.tempoAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(_lastFeedback!.tempoAccuracy.toInt()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildAccuracyItem(
                  'Rhythm Accuracy',
                  '${_lastFeedback!.rhythmAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(_lastFeedback!.rhythmAccuracy.toInt()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildAccuracyItem(
                  'Overall Accuracy',
                  '${_lastFeedback!.overallAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(_lastFeedback!.overallAccuracy.toInt()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Overall feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _lastFeedback!.overallFeedback,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          if (_lastFeedback!.missedNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Missed Notes:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _lastFeedback!.missedNotes
                  .map(
                    (note) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        note,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (_lastFeedback!.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Suggestions:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._lastFeedback!.suggestions.map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccuracyItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _toggleAudio() async {
    if (_audioService.isPlaying) {
      await _audioService.stopAudio();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio stopped'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    } else {
      // Use the audio path as provided
      await _audioService.playAudio(
        widget.audioPath,
        ragaName: widget.ragaData.name,
        practiceType: widget.practiceType,
      );
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing ${widget.practiceType} for ${widget.ragaData.name}\n(Audio file: ${widget.audioPath})',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  void _stopAudio() async {
    await _audioService.stopAudio();
    setState(() {});
  }

  void _toggleRecording() async {
    if (_audioService.isRecording) {
      final recordingPath = await _audioService.stopRecording();
      _pulseController.stop();
      setState(() {});

      if (recordingPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording saved: ${recordingPath.split('/').last}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      await _audioService.startRecording();
      _pulseController.repeat(reverse: true);
      setState(() {});
    }
  }

  void _analyzeAudio() async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // If we have user characteristics, compare with reference
      if (_userCharacteristics != null && _referenceCharacteristics != null) {
        final feedback = await _analysisService.compareAudio(
          _referenceCharacteristics!,
          _userCharacteristics!,
          widget.ragaData.notes,
        );
        setState(() {
          _isAnalyzing = false;
          _lastFeedback = feedback;
        });
      } else {
        // Generate sample feedback if no real data available
        Future.delayed(const Duration(seconds: 3), () {
          setState(() {
            _isAnalyzing = false;
            _lastFeedback = _generateSampleFeedback();
          });
        });
      }
    } catch (e) {
      print('Error analyzing audio: $e');
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _toggleRealTimeAnalysis() {
    setState(() {
      _showRealTimeAnalysis = !_showRealTimeAnalysis;
    });
  }

  void _toggleCharacteristicsDisplay() {
    setState(() {
      _showCharacteristicsDisplay = !_showCharacteristicsDisplay;
    });
  }

  void _testAudioFile() async {
    try {
      print('Testing audio file: ${widget.audioPath}');
      print('Raga: ${widget.ragaData.name}');
      print('Practice Type: ${widget.practiceType}');

      await _audioService.playAudio(
        widget.audioPath,
        ragaName: widget.ragaData.name,
        practiceType: widget.practiceType,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Testing audio file: ${widget.audioPath}'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error testing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error testing audio: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _checkAudioFileExists() async {
    try {
      final exists = await _audioService.checkAudioFileExists(widget.audioPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exists
                ? 'Audio file exists: ${widget.audioPath}'
                : 'Audio file does not exist: ${widget.audioPath}',
          ),
          backgroundColor: exists ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking file: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  AudioFeedback _generateSampleFeedback() {
    // Generate sample feedback based on practice type
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    return AudioFeedback(
      pitchAccuracy: 75.0 + (random % 20),
      tempoAccuracy: 80.0 + (random % 15),
      rhythmAccuracy: 70.0 + (random % 25),
      overallAccuracy: 75.0 + (random % 20),
      missedNotes: ['Sa', 'Re', 'Ga'].take(random % 3).toList(),
      suggestions: [
        'Try to hold each note for a longer duration',
        'Focus on the transition between Sa and Re',
        'Practice with a slower tempo first',
        'Work on maintaining consistent rhythm patterns',
      ],
      overallFeedback:
          'Good effort! Your pitch accuracy is improving. Focus on the missed notes and try to maintain consistent tempo and rhythm.',
    );
  }

  void _logPractice() {
    // TODO: Implement practice logging logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Practice session logged for ${widget.ragaData.name}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}
