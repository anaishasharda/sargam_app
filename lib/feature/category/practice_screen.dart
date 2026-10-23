// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sargam_app/services/audio_service.dart';
import 'package:sargam_app/services/audio_analysis_service.dart';
import 'package:sargam_app/services/app_state_service.dart';
import 'package:sargam_app/services/normalized_compare.dart';
import 'package:sargam_app/services/sa_pitch.dart';

import '../../models/audio_feedback.dart';
import '../../models/audio_characteristics.dart';
import '../../models/raag_entry.dart';
import '../../models/practice_session.dart';
import '../../models/journal_entry.dart';
import '../../models/alankar.dart';
import '../../services/tone_synth_service.dart';
import '../../services/realtime_audio_service.dart';
import '../../widgets/pitch_graph.dart';
import '../profile/sa_calibration_screen.dart';
import 'real_time_audio_analysis.dart';
import 'audio_characteristics_display.dart';

class PracticeScreen extends StatefulWidget {
  final RagaData ragaData;
  final String practiceType;
  final String audioPath;

  /// When non-null, the screen runs in Alankar mode: reference audio is
  /// synthesized from the alankar's sargam pattern at the chosen tempo and
  /// transpose, and the sing-along graph drives off that pattern instead of
  /// the raga's audio file.
  final Alankar? alankar;

  const PracticeScreen({
    super.key,
    required this.ragaData,
    required this.practiceType,
    required this.audioPath,
    this.alankar,
  });

  bool get isAlankar => alankar != null;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final AudioAnalysisService _analysisService = AudioAnalysisService();
  final ToneSynthService _toneSynth = ToneSynthService();
  final RealtimeAudioService _realtimeAudio = RealtimeAudioService();

  bool _isAnalyzing = false;
  AudioFeedback? _lastFeedback;
  AudioCharacteristics? _referenceCharacteristics;
  bool _usedReferenceFallback = false;
  AudioCharacteristics? _userCharacteristics;
  final bool _showRealTimeAnalysis = false;
  bool _showCharacteristicsDisplay = false;
  String? _recordedAudioPath;
  bool _hasRecording = false;

  // Sing-along graph state.
  int _transpose = 0;        // 0..5 semitones up
  int _bpm = 80;             // 80 or 100 for now
  TargetTrack? _targetTrack;
  bool _showSingAlong = false;


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
    _analysisService.initialize();
    _realtimeAudio.initialize();
    _requestPermissions();
    // The Stop button's truthfulness depends on the tone synth's playing
    // state too; rebuild when it changes (a pattern ends silently).
    _tonePlayingSub = _toneSynth.player.playingStream.listen((_) {
      if (mounted) setState(() {});
    });
  }
  /// Subscription to the tone synth's playing state (see initState).
  StreamSubscription<bool>? _tonePlayingSub;

  @override
  void dispose() {
    if (mounted) {
      _tonePlayingSub?.cancel();
      _pulseController.dispose();
      
      // Stop any active recording so the mic is freed and state is reset
      // for the next time the user visits this screen.
      if (_audioService.isRecording) {
        // ignore: discarded_futures
        _audioService.stopRecording();
      }
      
      // Do not dispose audio service as it is a singleton and needed for future playback
      _audioService.stopAudio();
      _toneSynth.stop();
      // External-mode analysis is owned by AudioService.stopRecording();
      // calling stopExternalAnalysis here is a no-op safety net.
      _realtimeAudio.stopExternalAnalysis();
      _analysisService.dispose();
    }
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await _audioService.requestPermissions();
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
        foregroundColor: Colors.white,
        title: Text('${widget.practiceType} - ${widget.ragaData.name}'),
        elevation: 0,
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
                    Colors.deepPurpleAccent.withValues(alpha: 0.2),
                    Colors.purpleAccent.withValues(alpha: 0.1),
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
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${widget.ragaData.notes.join(' ')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Transpose + tempo controls
            _buildScaleAndTempoControls(),

            const SizedBox(height: 16),

            // Live pitch graph (shown while recording).
            // Shows target notes as orange bars and the user's real-time
            // pitch as a smooth Bezier curve with note labels on the Y-axis.
            if (_showSingAlong && _targetTrack != null) ...[
              PitchGraph(
                target: _targetTrack!,
                liveStream: _realtimeAudio.dataStream,
                waveformStream: _realtimeAudio.waveformStream,
              ),
              const SizedBox(height: 16),
            ],

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
                      () => _playReferenceAudio(),
                      enabled: !_audioService.isRecording &&
                          !_audioService.isPlaying &&
                          !_isAnalyzing,
                    ),
                    _controlButton(
                      'Stop',
                      Icons.stop,
                      Colors.red,
                      _audioService.isPlaying || _toneSynth.player.playing,
                      () => _stopReferenceAudio(),
                      enabled: !_audioService.isRecording &&
                          (_audioService.isPlaying ||
                              _toneSynth.player.playing),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Plan 3b: without a stored Sa the analysis
                // cannot be trusted, so recording is gated
                // until the student sets one. Calibration's
                // best-try save guarantees an exit.
                if (context.read<AppStateService>().currentUser?.baseSaHz == null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Your Sa isn\'t set yet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Set it so your feedback matches your voice — it takes a minute.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SaCalibrationScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.music_note),
                          label: const Text('Find Your Sa'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Practice controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      _audioService.isRecording
                          ? 'Stop Recording'
                          : 'Record Practice',
                      _audioService.isRecording
                          ? Icons.stop
                          : Icons.fiber_manual_record,
                      _audioService.isRecording
                          ? Colors.red
                          : Colors.orange,
                      _audioService.isRecording,
                      () => _toggleRecording(),
                      enabled: context.read<AppStateService>().currentUser?.baseSaHz != null && !_audioService.isPlaying && !_isAnalyzing,
                    ),
                    _controlButton(
                      'Analyze Audio',
                      Icons.analytics,
                      _hasRecording ? Colors.purple : Colors.grey,
                      _isAnalyzing,
                      () => _analyzeAudio(),
                      enabled: _hasRecording && !_isAnalyzing,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // // Analysis controls
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //   children: [
                //     _controlButton(
                //       'Real-time Analysis',
                //       Icons.radio_button_checked,
                //       Colors.cyan,
                //       _showRealTimeAnalysis,
                //       () => _toggleRealTimeAnalysis(),
                //     ),
                //     _controlButton(
                //       'Show Characteristics',
                //       Icons.bar_chart,
                //       Colors.teal,
                //       _showCharacteristicsDisplay,
                //       () => _toggleCharacteristicsDisplay(),
                //     ),
                //   ],
                // ),

                // const SizedBox(height: 16),

                // // Debug controls
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //   children: [
                //     _controlButton(
                //       'Test Audio File',
                //       Icons.audiotrack,
                //       Colors.indigo,
                //       false,
                //       () => _testAudioFile(),
                //     ),
                //     _controlButton(
                //       'Check File Exists',
                //       Icons.search,
                //       Colors.brown,
                //       false,
                //       () => _checkAudioFileExists(),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 32),

                // Recording ready indicator
                if (_hasRecording && !_audioService.isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Recording Ready for Analysis',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                            color: Colors.orange.withValues(alpha: 0.3),
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
                      color: Colors.purple.withValues(alpha: 0.3),
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
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    onPressed: _lastFeedback == null ? null : () => _logPractice(),
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
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : Colors.grey;
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isActive ? effectiveColor : effectiveColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isActive
                  ? effectiveColor
                  : effectiveColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: isActive ? Colors.white : effectiveColor,
              size: 32,
            ),
            onPressed: enabled ? onPressed : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildScaleAndTempoControls() {
    final isRecording = _audioService.isRecording;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.deepPurpleAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Scale (Transpose)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                _transpose == 0 ? 'Original' : '+$_transpose semitones',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(6, (i) {
              final selected = _transpose == i;
              return Expanded(
                child: GestureDetector(
                  onTap: isRecording
                      ? null
                      : () => setState(() {
                            _transpose = i;
                            _targetTrack = null; // force rebuild on next play
                          }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? Colors.deepPurpleAccent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      'T$i',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.deepPurpleAccent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Tempo',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '$_bpm BPM',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [80, 100].map((bpm) {
              final selected = _bpm == bpm;
              return Expanded(
                child: GestureDetector(
                  onTap: isRecording
                      ? null
                      : () => setState(() {
                            _bpm = bpm;
                            _targetTrack = null;
                          }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.deepPurpleAccent
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? Colors.deepPurpleAccent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      '$bpm BPM',
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  final Stopwatch _practiceStopwatch = Stopwatch();

  void _toggleRecording() async {
    if (_audioService.isRecording) {
      final recordingPath = await _audioService.stopRecording();
      _pulseController.stop();
      _practiceStopwatch.stop();
      // Real-time analysis is stopped inside _audioService.stopRecording()
      // because the recorder owns the mic stream. No-op here.

      setState(() {
        _recordedAudioPath = recordingPath;
        _hasRecording = recordingPath != null;
        _showSingAlong = false;
        // Clear previous analysis when new recording is made
        _lastFeedback = null;
        _userCharacteristics = null;
      });

      if (recordingPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording saved! You can now analyze it.\n${recordingPath.split('/').last}',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      // Clear previous recording when starting a new one
      setState(() {
        _recordedAudioPath = null;
        _hasRecording = false;
        _lastFeedback = null;
        _userCharacteristics = null;
      });

      // Tokens that drive the graph target bars.
      final tokens = widget.isAlankar
          ? withDescendingMirror(widget.alankar!.pattern)
          : widget.ragaData.notes;

      // Build the target track for the graph WITHOUT playing audio.
      // Previously, playPattern() was used here which played synthesized
      // piano notes through the speaker. On iOS, this triggers the system's
      // echo cancellation which suppresses the microphone input to near-zero,
      // making pitch detection impossible.
      final storedSaHz = context.read<AppStateService>().currentUser?.baseSaHz;
      final track = _toneSynth.buildTrack(
        tokens: tokens,
        bpm: _bpm,
        transposeSemitones: _transpose,
        baseSaHz: storedSaHz,
      );

      // Start recording AFTER building the track (mic-only, no playback).
      await _audioService.startRecording();

      _pulseController.repeat(reverse: true);
      _practiceStopwatch.reset();
      _practiceStopwatch.start();

      setState(() {
        _targetTrack = track;
        _showSingAlong = true;
      });
    }
  }


  void _analyzeAudio() async {
    // Check if user has recorded audio
    if (!_hasRecording || _recordedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please record your voice first before analyzing!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    // Plan 1.8: the signed-in student's stored Sa (Patch 3a), read
    // synchronously here, before any await in this method. Null when the
    // student has not calibrated yet — compareAudio then uses its legacy
    // pitch scoring.
    final userSaHz = context.read<AppStateService>().currentUser?.baseSaHz;

    try {
      // Show analyzing message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analyzing your recording...'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      // Analyze the reference audio if not already done
      if (_referenceCharacteristics == null) {
        print('Analyzing reference audio: ${widget.audioPath}');
        _usedReferenceFallback = false;

        // Get the asset file as a temporary file for analysis
        final referenceFile = await _audioService.getAssetFile(
          widget.audioPath,
        );

        if (referenceFile != null && await referenceFile.exists()) {
          _referenceCharacteristics = await _analysisService.analyzeAudioFile(
            referenceFile.path,
          );
          print('Reference analysis complete');

          // MP4 files will fail to parse and return empty characteristics.
          // If so, we need a valid fallback so the comparison doesn't instantly return 30%.
          if (_isEmptyCharacteristics(_referenceCharacteristics!)) {
            print(
              'Reference file could not be parsed as WAV. Using valid fallback reference.',
            );
            _referenceCharacteristics = AudioCharacteristics(
              pitch: 261.63, // Middle C fallback
              tempo: 60.0, // Standard tempo fallback
              rhythm: const [1.0, 0.5, 1.0, 0.5], // Non-empty rhythm fallback
              notes: widget.ragaData.notes,
              volume: 0.5,
              spectrum: const [],
              duration: 5.0,
            );
            _usedReferenceFallback = true;
          } else {
            print('Reference notes: ${_referenceCharacteristics?.notes}');
          }
        } else {
          print('Failed to load reference audio file: ${widget.audioPath}');
          // Fallback to raga notes if file analysis fails (better than nothing)
          _referenceCharacteristics = AudioCharacteristics(
            pitch: 261.63, // Fallback
            tempo: 60.0,
            rhythm: const [1.0, 0.5, 1.0, 0.5], // Non-empty rhythm fallback
            notes: widget.ragaData.notes,
            volume: 0.5,
            spectrum: const [],
            duration: 5.0,
          );
          _usedReferenceFallback = true;
        }
      }

      // Verify the recording file exists before analysis
      final recordingFile = File(_recordedAudioPath!);
      if (!await recordingFile.exists()) {
        throw Exception(
          'Recording file not found. Please try recording again.',
        );
      }
      final fileSize = await recordingFile.length();
      print('Recording file size: $fileSize bytes');
      if (fileSize < 1000) {
        throw Exception(
          'Recording file is too small. Please record for longer.',
        );
      }

      // Analyze the user's recorded audio
      print('Analyzing user recording: $_recordedAudioPath');
      _userCharacteristics = await _analysisService.analyzeAudioFile(
        _recordedAudioPath!,
      );
      print('User recording analysis complete');
      if (_isEmptyCharacteristics(_userCharacteristics!)) {
        throw Exception(
          'We could not detect enough audio data. Please record again with a clearer voice.',
        );
      }

      // Compare both audio files
      print('Comparing audio files...');
      // Plan 1.8: estimate the reference's Sa from its own contour. An
      // estimate of 0 means it could not be estimated (e.g. the fallback
      // dummy reference, which has no contour) and leaves the legacy pitch
      // scoring in place.
      final estimatedReferenceSaHz = estimateSaFromContour(
        _referenceCharacteristics!.pitchTrajectory,
      );
      print(
        'Sa for comparison - user: $userSaHz Hz, reference estimate: ${estimatedReferenceSaHz.toStringAsFixed(2)} Hz',
      );
      final driftCheck = checkSaDrift(
        userTrajectoryHz: _userCharacteristics!.pitchTrajectory,
        storedSaHz: userSaHz,
      );
      if (driftCheck != null) {
        print('Sa drift check: $driftCheck');
      }
      final feedback = await _analysisService.compareAudio(
        _referenceCharacteristics!,
        _userCharacteristics!,
        widget.ragaData.notes,
        userSaHz: userSaHz,
        referenceSaHz: estimatedReferenceSaHz > 0
            ? estimatedReferenceSaHz
            : null,
        table: RagaSwaraTable.forRaga(widget.ragaData.name),
      );
      print('Comparison complete');

      setState(() {
        _isAnalyzing = false;
        _lastFeedback = feedback;
        _showCharacteristicsDisplay = true;
      });

      if (_usedReferenceFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Warning: the reference recording could not be analyzed. '
              'Scores are compared against a default reference, not the recording.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analysis complete! Check your results below.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error analyzing audio: $e');
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing audio: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _logPractice() async {
    final appState = context.read<AppStateService>();
    final currentUser = appState.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to log practice sessions'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show practice logging dialog
    _showPracticeLogDialog(appState, currentUser.id!);
  }

  void _showPracticeLogDialog(AppStateService appState, String userId) {
    final TextEditingController notesController = TextEditingController();

    // Calculate effective practice time
    final Duration elapsed = _practiceStopwatch.elapsed;
    // Minimum 1 minute if recorded, otherwise 0
    // But better to show actual seconds if less than a minute?
    // User asked: "it is showing the static time of 1 min everytime, it should be dynamic depending upon the time i practiced"
    // So let's show exact minutes and seconds.

    // For the database we store integer minutes (based on existing model),
    // but maybe we should store seconds or at least round properly.
    // The current model has `int practiceTime` (minutes).
    // I will round to nearest minute, but ensure at least 1 if > 30s?
    // Let's stick to minutes for the DB for now to avoid breaking changes,
    // but display nice formatted text.

    int practiceTimeMinutes = elapsed.inMinutes;
    if (elapsed.inSeconds > 30 && practiceTimeMinutes == 0) {
      practiceTimeMinutes = 1;
    }

    // If manually entered/no recording, keep existing logic or default to 0
    if (!_hasRecording && practiceTimeMinutes == 0) {
      practiceTimeMinutes = 0;
    }

    String timeDisplay = '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Log Practice Session'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Raga: ${widget.ragaData.name}'),
                Text('Type: ${widget.practiceType}'),
                const SizedBox(height: 16),

                // Display practice time directly
                Text(
                  'Practice Time: $timeDisplay',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 16),

                // Notes field
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Practice Notes (Optional)',
                    hintText: 'How did the practice session go?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _savePracticeSession(
                appState,
                userId,
                practiceTimeMinutes,
                notesController.text,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePracticeSession(
    AppStateService appState,
    String userId,
    int practiceTime,
    String notes,
  ) async {
    Navigator.of(context).pop(); // Close dialog

    try {
      // Create practice session
      final practiceSession = PracticeSession(
        userId: userId,
        date: DateTime.now(),
        raga: widget.ragaData.name,
        type: widget.practiceType,
        missedNotes:
            _lastFeedback?.missedNotes
                .map(
                  (note) => MissedNote(
                    note: note,
                    count: 1,
                    expectedPitch: 'Unknown',
                    actualPitch: 'Unknown',
                  ),
                )
                .toList() ??
            [],
        tempo: 80, // Default tempo
        pitchAccuracy: _lastFeedback?.pitchAccuracy.round() ?? 75,
        practiceTime: practiceTime,
        overallAccuracy: _lastFeedback?.overallAccuracy,
        tempoAccuracy: _lastFeedback?.tempoAccuracy,
        rhythmAccuracy: _lastFeedback?.rhythmAccuracy,
        // Populate detailed fields from the local analysis only
        avgPitch: _userCharacteristics?.pitch,
        avgVolume: null, // Volume parameter is removed per request
        bpm: _userCharacteristics?.tempo,
        detectedNotes: _userCharacteristics?.notes,
        brightness: _userCharacteristics?.spectralCentroid,
        stability: _userCharacteristics?.qualityScore,
      );

      await appState.addPracticeSession(practiceSession);

      // Create journal entry if notes provided
      if (notes.isNotEmpty) {
        final journalEntry = JournalEntry(
          userId: userId,
          date: DateTime.now(),
          raga: widget.ragaData.name,
          sur: 'Mixed', // Default value
          taal: 'Free', // Default value
          type: widget.practiceType,
          notes: notes,
          pitchAccuracy: _lastFeedback?.pitchAccuracy.round() ?? 75,
          practiceTime: practiceTime,
          avgPitch: _userCharacteristics?.pitch,
          avgVolume: null,
          bpm: _userCharacteristics?.tempo,
          detectedNotes: _userCharacteristics?.notes,
          brightness: _userCharacteristics?.spectralCentroid,
          stability: _userCharacteristics?.qualityScore,
        );

        await appState.addJournalEntry(journalEntry);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Practice session logged for ${widget.ragaData.name}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log practice session: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }

  bool _isEmptyCharacteristics(AudioCharacteristics characteristics) {
    return characteristics.pitch == 0.0 &&
        characteristics.tempo == 0.0 &&
        characteristics.notes.isEmpty &&
        characteristics.volume == 0.0 &&
        characteristics.spectrum.isEmpty;
  }

  Future<void> _playReferenceAudio() async {
    if (widget.isAlankar) {
      final storedSaHz = context.read<AppStateService>().currentUser?.baseSaHz;
      final tokens = withDescendingMirror(widget.alankar!.pattern);
      final track = await _toneSynth.playPattern(
        tokens: tokens,
        bpm: _bpm,
        transposeSemitones: _transpose,
        baseSaHz: storedSaHz,
      );
      setState(() {
        _targetTrack = track;
      });
    } else {
      final storedSaHz = context.read<AppStateService>().currentUser?.baseSaHz;
      await _audioService.playAudio(
        widget.audioPath,
        ragaName: widget.ragaData.name,
        practiceType: widget.practiceType,
        transposeSemitones: _transpose,
        // Map BPM selection to a playback speed multiplier; 80 BPM is
        // treated as the asset's natural pace (matches the default selection).
        speed: _bpm / 80.0,
      );
      // For raga aaroh/avroh, derive a target track from the raga notes at the
      // chosen BPM. This is a simple grid-based fallback; a future improvement
      // could pitch-detect the actual reference asset.
      setState(() {
        _targetTrack = _toneSynth.buildTrack(
          tokens: widget.ragaData.notes,
          bpm: _bpm,
          transposeSemitones: _transpose,
          baseSaHz: storedSaHz,
        );
      });
    }
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Playing ${widget.practiceType} for ${widget.ragaData.name}',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  Future<void> _stopReferenceAudio() async {
    await _audioService.stopAudio();
    await _toneSynth.stop();
    setState(() {});
    if (!mounted) return;
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
  }
}
