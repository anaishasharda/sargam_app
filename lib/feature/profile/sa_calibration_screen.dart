import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state_service.dart';
import '../../services/audio_analysis_service.dart';
import '../../services/audio_service.dart';
import '../../services/sa_pitch.dart';
import '../../services/tone_synth_service.dart';

/// Plan 3b: "Find your Sa" — the student-facing calibration screen.
///
/// The app proposes, the student confirms: three steady held-Sa takes
/// are agreed by [calibrateSa], the proposed Sa is played back, and only
/// the student's "That's my Sa" tap saves it. Nothing here ever blocks
/// practice — a student can leave at any point and calibrate later from
/// Profile. Student-facing copy uses musical language only (no Hz, no
/// cents); the pitch is named the way a classroom names it ("G#").
class SaCalibrationScreen extends StatefulWidget {
  const SaCalibrationScreen({super.key});

  @override
  State<SaCalibrationScreen> createState() => _SaCalibrationScreenState();
}

class _SaCalibrationScreenState extends State<SaCalibrationScreen> {
  final AudioService _audioService = AudioService();
  final AudioAnalysisService _analysisService = AudioAnalysisService();
  final ToneSynthService _toneSynth = ToneSynthService();

  final List<SaTakeResult> _steadyTakes = [];
  List<double> _lastSetMedians = [];

  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _isSaving = false;
  int _takeToken = 0;
  int _setsFailed = 0;

  SaCalibration? _proposal;
  bool _saved = false;
  String _message =
      'Sing your Sa — the home note you sing everything from — and hold '
      'it steady. We will listen three times.';

  @override
  void initState() {
    super.initState();
    _analysisService.initialize();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await _audioService.requestPermissions();
  }

  @override
  void dispose() {
    if (_isRecording) {
      unawaited(_audioService.stopRecording());
    }
    unawaited(_toneSynth.stop());
    super.dispose();
  }

  // --- recording + per-take analysis ---------------------------------------

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndAnalyze();
      return;
    }
    // startRecording does real async work (permission check, file open,
    // recorder start) and only then flips isRecording; it reports failure
    // by leaving isRecording false, never by throwing. It must be awaited
    // before the state is read — reading it synchronously here raced the
    // start and showed the permission message on every cold start while
    // the recorder started anyway (the alternating two-tries bug).
    await _audioService.startRecording();
    if (!mounted) return;
    setState(() {
      _isRecording = _audioService.isRecording;
      _message = _isRecording
          ? 'Recording — hold your Sa steady…'
          : 'The microphone did not start. Check the app has mic '
              'permission, then try again.';
    });
    if (!_isRecording) return;
    // Guided shape: every take is a ~5 second hold, so analyzeSaTake's
    // middle slice is always a sustained note, never a performance.
    final token = ++_takeToken;
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isRecording && token == _takeToken) {
        unawaited(_stopAndAnalyze());
      }
    });
  }

  Future<void> _stopAndAnalyze() async {
    final path = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });
    if (path == null) {
      setState(() {
        _isAnalyzing = false;
        _message = 'That take did not save. Try once more.';
      });
      return;
    }
    final characteristics = await _analysisService.analyzeAudioFile(path);
    final slice = _middleSlice(characteristics.pitchTrajectory);
    final result = analyzeSaTake(slice);
    // TEMP diagnostic, calibration-stability investigation (2026-10-21):
    // prints each take's spread so the 25c steadiness limit can be tuned
    // from real voices instead of guessed. Remove once tuned.
    final voicedCount = slice.where((s) => s > 0).length;
    if (result == null) {
      print('Sa calibration take: no voiced samples '
          '(slice=${slice.length}, voiced=$voicedCount)');
    } else {
      var maxDevCents = 0.0;
      for (final s in slice) {
        if (s <= 0) continue;
        final dev = centsFromSa(s, result.medianHz).abs();
        if (dev > maxDevCents) maxDevCents = dev;
      }
      print('Sa calibration take: '
          'median=${result.medianHz.toStringAsFixed(2)} Hz, '
          'stdDev=${result.stdDevCents.toStringAsFixed(1)}c, '
          'maxDev=${maxDevCents.toStringAsFixed(0)}c, '
          'stable=${result.isStable} '
          '(slice=${slice.length}, voiced=$voicedCount)');
    }
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      if (result == null) {
        _message = 'I couldn\'t hear that clearly. Move a little closer '
            'and sing out — then try again.';
      } else if (!result.isStable) {
        _message = 'That one wobbled a bit. Hold it like a steady line — '
            'once more.';
      } else {
        _steadyTakes.add(result);
        if (_steadyTakes.length < 3) {
          _message = 'Steady — that\'s ${_steadyTakes.length} of 3.';
        }
      }
    });
    if (result != null && result.isStable && _steadyTakes.length == 3) {
      _finishSet();
    }
  }

  /// analyzeSaTake's contract: only the middle of the take (attack and
  /// release skipped).
  List<double> _middleSlice(List<double> samples) {
    if (samples.length < 8) return samples;
    final quarter = samples.length ~/ 4;
    return samples.sublist(quarter, samples.length - quarter);
  }

  // --- set completion, failure budget, proposals ---------------------------

  void _finishSet() {
    _lastSetMedians = [for (final t in _steadyTakes) t.medianHz];
    final calibration = calibrateSa(_steadyTakes);
    _steadyTakes.clear();
    if (calibration != null) {
      _propose(calibration, isBestTry: false);
      return;
    }
    _setsFailed++;
    if (_setsFailed >= 2) {
      // Never trap a student in a retake loop: offer the best try from
      // the steady takes just sung, saved at 'ok' confidence. The
      // drift check and a later recalibration are the repair path.
      _propose(
        SaCalibration(
          saHz: _median(_lastSetMedians),
          agreementCents: 30.0,
          calibratedAt: DateTime.now(),
        ),
        isBestTry: true,
      );
    } else {
      setState(() {
        _message = 'Your takes didn\'t quite agree with each other. '
            'Let\'s do the set once more — same Sa each time.';
      });
    }
  }

  void _propose(SaCalibration calibration, {required bool isBestTry}) {
    setState(() {
      _proposal = calibration;
      _message = isBestTry
          ? 'Your takes didn\'t quite agree, so here is your best try. '
              'Have a listen — does it sound like your Sa?'
          : 'Here is the Sa we heard. Have a listen — does it sound '
              'like yours?';
    });
    unawaited(_playProposal());
  }

  Future<void> _playProposal() async {
    final calibration = _proposal;
    if (calibration == null) return;
    await _toneSynth.playPattern(
      tokens: const ['Sa'],
      bpm: 20,
      transposeSemitones: 0,
      baseSaHz: calibration.saHz,
    );
  }

  void _rejectProposal() {
    unawaited(_toneSynth.stop());
    setState(() {
      _proposal = null;
      _setsFailed++;
      _message = _setsFailed >= 2
          ? 'No problem. You can set your Sa any time from Profile — '
              'or try again now.'
          : 'No problem — sing it once more when you are ready.';
    });
  }

  // --- saving ---------------------------------------------------------------

  Future<void> _saveProposal() async {
    final calibration = _proposal;
    if (calibration == null) return;
    final appState = context.read<AppStateService>();
    final user = appState.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not signed in.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final updatedUser = user.copyWith(
        baseSaHz: calibration.saHz,
        saCalibratedAt: calibration.calibratedAt,
        saConfidence: calibration.confidence,
      );
      await appState.updateUserProfile(updatedUser);
      unawaited(_toneSynth.stop());
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saved = true;
          _proposal = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save your Sa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Classroom name for a pitch: 207.65 Hz -> "G#3".
  String _pitchName(double hz) {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    ];
    final midi = (69 + 12 * (math.log(hz / 440) / math.log(2))).round();
    return '${names[midi % 12]}${(midi ~/ 12) - 1}';
  }

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Sa'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _saved ? _buildSaved() : _buildFlow(),
      ),
    );
  }

  Widget _buildSaved() {
    final user = context.read<AppStateService>().currentUser;
    final saHz = user?.baseSaHz;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 72, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          saHz == null ? 'Your Sa is set.' : 'Your Sa is set: ${_pitchName(saHz)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildFlow() {
    final proposal = _proposal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.music_note, size: 48),
        const SizedBox(height: 16),
        Text(
          _message,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (proposal == null) ...[
          _buildProgressDots(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: (_isAnalyzing || _isSaving) ? null : _toggleRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.red : Colors.deepPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            label: Text(
              _isAnalyzing
                  ? 'Listening…'
                  : _isRecording
                      ? 'Stop Recording'
                      : 'Record Take',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'You can do this any time from Profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ] else ...[
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _playProposal,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Hear It Again'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveProposal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.check),
            label: const Text('That\'s My Sa'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isSaving ? null : _rejectProposal,
            child: const Text('Not Quite — Try Again'),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              i < _steadyTakes.length
                  ? Icons.circle
                  : Icons.circle_outlined,
              size: 16,
              color: Colors.deepPurple,
            ),
          ),
      ],
    );
  }
}
