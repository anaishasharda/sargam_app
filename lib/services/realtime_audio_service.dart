import 'dart:async';
import 'dart:math' as math;
// import 'dart:typed_data'; // Not needed, using Flutter foundation
import 'package:flutter/foundation.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
// import 'package:waveform_fft/waveform_fft.dart'; // Package may not be available
import 'package:fftea/fftea.dart';
// import '../models/audio_characteristics.dart'; // Not directly used
import '../services/indian_music_helper.dart';

/// Enhanced real-time audio analysis service with live microphone input
class RealtimeAudioService {
  static final RealtimeAudioService _instance =
      RealtimeAudioService._internal();
  factory RealtimeAudioService() => _instance;
  RealtimeAudioService._internal();

  // Audio capture components
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();

  // Analysis components
  FFT? _fft;
  bool _initialized = false;
  bool _isAnalyzing = false;
  bool _externalSourceMode = false;

  // Real-time data streams
  final StreamController<RealtimeAudioData> _dataController =
      StreamController.broadcast();
  final StreamController<List<double>> _waveformController =
      StreamController.broadcast();
  final StreamController<List<double>> _spectrumController =
      StreamController.broadcast();

  // Audio processing parameters
  static const int _sampleRate = 44100;
  static const int _windowSize = 2048;
  static const int _bufferSize = 44100; // Increased to 1 second of audio

  // Audio buffer for analysis
  final List<double> _audioBuffer = [];
  final List<double> _pitchHistory = [];
  final List<double> _volumeHistory = [];
  final List<double> _tempoHistory = [];

  // Analysis timing
  Timer? _analysisTimer;

  // Getters for streams
  Stream<RealtimeAudioData> get dataStream => _dataController.stream;
  Stream<List<double>> get waveformStream => _waveformController.stream;
  Stream<List<double>> get spectrumStream => _spectrumController.stream;

  bool get isAnalyzing => _isAnalyzing;

  /// Initialize the real-time audio service. Idempotent — safe to call
  /// from multiple screens / multiple times.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _fft = FFT(_windowSize);
      _initialized = true;
      debugPrint('✅ RealtimeAudioService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing RealtimeAudioService: $e');
      throw Exception('Failed to initialize real-time audio service: $e');
    }
  }

  /// Begin emitting analysis events from samples that the caller will push
  /// in via [feedSamples]. Use this when something else owns the microphone
  /// (e.g. a file recorder running [Record.startStream]) — avoids two
  /// platform mic clients fighting over the same input.
  Future<void> startExternalAnalysis() async {
    if (_isAnalyzing) return;
    if (!_initialized) await initialize();
    _isAnalyzing = true;
    _externalSourceMode = true;
    _audioBuffer.clear();
    _pitchHistory.clear();
    _volumeHistory.clear();
    _tempoHistory.clear();
    _recentPitches.clear();
    _startPeriodicAnalysis();
    debugPrint('✅ External-source analysis started');
  }

  /// Stop an external-source analysis session started via
  /// [startExternalAnalysis]. The caller is responsible for stopping its
  /// own audio source.
  Future<void> stopExternalAnalysis() async {
    if (!_isAnalyzing || !_externalSourceMode) return;
    _isAnalyzing = false;
    _externalSourceMode = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _audioBuffer.clear();
    _pitchHistory.clear();
    _volumeHistory.clear();
    _tempoHistory.clear();
    _recentPitches.clear();
    debugPrint('🛑 External-source analysis stopped');
  }

  /// Push a chunk of float audio samples (range ~[-1, 1]) into the analysis
  /// pipeline. No-op if analysis is not currently running.
  void feedSamples(Float32List samples) {
    if (!_isAnalyzing) return;
    debugPrint('📥 feedSamples: ${samples.length} samples, _isAnalyzing=$_isAnalyzing, bufLen=${_audioBuffer.length}');
    _onAudioDataFloat32(samples);
  }

  /// Start real-time audio analysis with microphone capture
  Future<void> startRealTimeAnalysis() async {
    if (_isAnalyzing) {
      throw Exception('Real-time analysis already in progress');
    }

    try {
      _isAnalyzing = true;
      _audioBuffer.clear();
      _pitchHistory.clear();
      _volumeHistory.clear();
      _tempoHistory.clear();
      _recentPitches.clear();

      debugPrint('🎤 Starting microphone capture...');

      // Start audio capture
      await _audioCapture.start(
        _onAudioDataFloat32,
        _onError,
        sampleRate: _sampleRate,
        bufferSize: _bufferSize,
      );

      // Start periodic analysis
      _startPeriodicAnalysis();

      debugPrint('✅ Real-time audio analysis started');
    } catch (e) {
      _isAnalyzing = false;
      debugPrint('❌ Error starting real-time analysis: $e');
      throw Exception('Failed to start real-time analysis: $e');
    }
  }

  /// Stop real-time audio analysis
  Future<void> stopRealTimeAnalysis() async {
    if (!_isAnalyzing) return;

    try {
      _isAnalyzing = false;

      // Stop audio capture
      await _audioCapture.stop();

      // Cancel analysis timer
      _analysisTimer?.cancel();
      _analysisTimer = null;

      // Clear buffers
      _audioBuffer.clear();
      _pitchHistory.clear();
      _volumeHistory.clear();
      _tempoHistory.clear();
      _recentPitches.clear();

      debugPrint('🛑 Real-time audio analysis stopped');
    } catch (e) {
      debugPrint('❌ Error stopping real-time analysis: $e');
    }
  }

  /// Handle incoming audio data from microphone (Float32List)
  void _onAudioDataFloat32(Float32List audioData) {
    if (!_isAnalyzing) return;

    try {
      // Convert Float32List to List<double>
      final samples = audioData.map((e) => e.toDouble()).toList();

      // Add to buffer
      _audioBuffer.addAll(samples);

      // Keep buffer size manageable (1 second)
      if (_audioBuffer.length > _bufferSize) {
        _audioBuffer.removeRange(0, _audioBuffer.length - _bufferSize);
      }

      // Send waveform data for visualization
      _waveformController.add(samples);
    } catch (e) {
      debugPrint('❌ Error processing audio data: $e');
    }
  }

  /// Handle audio capture errors
  void _onError(Object error) {
    debugPrint('❌ Audio capture error: $error');
    if (_isAnalyzing) {
      stopRealTimeAnalysis();
    }
  }

  /// Start periodic analysis of buffered audio
  void _startPeriodicAnalysis() {
    const analysisInterval = Duration(milliseconds: 100); // 10 FPS

    _analysisTimer = Timer.periodic(analysisInterval, (timer) {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }

      _performAnalysis();
    });
  }

  /// Perform comprehensive audio analysis
  void _performAnalysis() {
    if (_audioBuffer.length < _windowSize) return;

    try {
      // 1. Get the most recent audio window (RAW samples for pitch detection)
      final windowRaw = _audioBuffer.sublist(
        math.max(0, _audioBuffer.length - _windowSize),
      );

      // 2. Apply window function for spectral analysis
      final windowedSamples = _applyHammingWindow(windowRaw);

      // 3. Perform analysis
      final analysisData = _analyzeAudioWindow(windowRaw, windowedSamples);

      // Update history for tempo calculation
      _updateHistory(analysisData);

      // Calculate additional metrics
      final enhancedData = _enhanceAnalysisData(analysisData);

      // Send data to listeners
      _dataController.add(enhancedData);

      debugPrint('📊 Analysis: pitch=${enhancedData.pitch.toStringAsFixed(1)} Hz, vol=${enhancedData.volume.toStringAsFixed(4)}, notes=${enhancedData.notes}');

      // Send spectrum data for visualization
      _spectrumController.add(enhancedData.spectrum);
    } catch (e) {
      debugPrint('❌ Error in analysis: $e');
    }
  }

  /// Analyze a single audio window.
  /// [rawSamples] is used for pitch detection (more accurate).
  /// [windowedSamples] is used for spectral analysis.
  RealtimeAudioData _analyzeAudioWindow(
    List<double> rawSamples,
    List<double> windowedSamples,
  ) {
    // Calculate basic metrics
    final pitch = _calculatePitch(rawSamples);
    final volume = _calculateVolume(rawSamples);
    final spectrum = _calculateSpectrum(windowedSamples);

    // Detect notes
    final notes = _detectNotes(pitch, spectrum);

    // Calculate quality metrics
    final quality = _calculateAudioQuality(rawSamples, spectrum);
    final brightness = _calculateBrightness(spectrum);

    return RealtimeAudioData(
      timestamp: DateTime.now(),
      pitch: pitch,
      volume: volume,
      spectrum: spectrum,
      notes: notes,
      quality: quality,
      brightness: brightness,
      tempo: 0.0, // Will be calculated in enhancement step
      waveform: rawSamples.length > 100 ? rawSamples.sublist(0, 100) : rawSamples,
    );
  }

  /// Enhance analysis data with historical context
  RealtimeAudioData _enhanceAnalysisData(RealtimeAudioData data) {
    // Calculate tempo from pitch history
    final tempo = _calculateTempoFromHistory();

    // Get Indian music context
    final sargamNotes = data.notes
        .map(IndianMusicHelper.westernToSargamNote)
        .toList();
    final raga = IndianMusicHelper.identifyRaga(data.notes);

    return data.copyWith(
      tempo: tempo,
      sargamNotes: sargamNotes,
      identifiedRaga: raga,
    );
  }

  /// Update historical data for tempo calculation
  void _updateHistory(RealtimeAudioData data) {
    const maxHistoryLength = 50; // Keep last 5 seconds at 10 FPS

    _pitchHistory.add(data.pitch);
    _volumeHistory.add(data.volume);

    // Trim history
    if (_pitchHistory.length > maxHistoryLength) {
      _pitchHistory.removeAt(0);
      _volumeHistory.removeAt(0);
    }
  }

  /// Calculate tempo from pitch history
  double _calculateTempoFromHistory() {
    if (_pitchHistory.length < 10) return 0.0;

    // Simple onset detection based on volume changes
    final onsets = <int>[];
    const threshold = 0.1;

    for (int i = 1; i < _volumeHistory.length; i++) {
      final diff = _volumeHistory[i] - _volumeHistory[i - 1];
      if (diff > threshold) {
        onsets.add(i);
      }
    }

    if (onsets.length < 3) return 0.0;

    // Calculate average interval between onsets
    final intervals = <double>[];
    for (int i = 1; i < onsets.length; i++) {
      intervals.add((onsets[i] - onsets[i - 1]) * 0.1); // Convert to seconds
    }

    if (intervals.isEmpty) return 0.0;

    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    return avgInterval > 0 ? 60.0 / avgInterval : 0.0;
  }

  // Note: _convertBytesToSamples removed as we now use Float32List directly

  /// Apply Hamming window function
  List<double> _applyHammingWindow(List<double> samples) {
    final windowed = <double>[];
    final n = samples.length;

    for (int i = 0; i < n; i++) {
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (n - 1));
      windowed.add(samples[i] * window);
    }

    return windowed;
  }

  /// ──────────────────────────────────────────────────────────────────────────
  /// YIN pitch detection algorithm — the gold standard for monophonic voice.
  ///
  /// Why the previous approaches failed:
  ///  • Raw FFT peak: 21 Hz bin resolution → always snaps to the same bin
  ///    → constant flat line.
  ///  • Raw autocorrelation max-peak: often picks a harmonic (2× or 3×)
  ///    instead of the fundamental → wrong frequency or constant.
  ///
  /// YIN works differently:
  ///  1. Computes a *difference function* d(τ) between the signal and a
  ///     shifted copy of itself.
  ///  2. Normalises it cumulatively (CMND) so that the first reliable dip
  ///     below a threshold is the fundamental period, not a harmonic.
  ///  3. Parabolic interpolation gives sub-sample accuracy (~1 Hz).
  /// ──────────────────────────────────────────────────────────────────────────

  // Small history buffer for median smoothing (removes jitter)
  final List<double> _recentPitches = [];
  static const int _pitchMedianWindow = 5;

  double _calculatePitch(List<double> samples) {
    if (samples.length < _windowSize) return 0.0;

    final rms = _calculateVolume(samples);
    if (rms < 0.005) return 0.0; // silence gate

    final raw = _yinPitch(samples);

    // Median-of-N smoothing to remove single-frame outliers
    if (raw > 0) {
      _recentPitches.add(raw);
    } else {
      _recentPitches.add(0.0);
    }
    if (_recentPitches.length > _pitchMedianWindow) {
      _recentPitches.removeAt(0);
    }

    // Return the median of recent values
    final sorted = List<double>.from(_recentPitches)..sort();
    final median = sorted[sorted.length ~/ 2];

    return (median > 60 && median < 1200) ? median : 0.0;
  }

  /// Core YIN algorithm on [samples].
  double _yinPitch(List<double> samples) {
    // Use the most recent _windowSize samples
    final buf = samples.length > _windowSize
        ? samples.sublist(samples.length - _windowSize)
        : samples;
    final W = buf.length;
    final halfW = W ~/ 2;

    // ── Step 1: Difference function ──
    // d(τ) = Σ_{j=0}^{W/2-1} (buf[j] - buf[j+τ])²
    final diff = List<double>.filled(halfW, 0.0);
    for (int tau = 1; tau < halfW; tau++) {
      double sum = 0.0;
      for (int j = 0; j < halfW; j++) {
        final delta = buf[j] - buf[j + tau];
        sum += delta * delta;
      }
      diff[tau] = sum;
    }

    // ── Step 2: Cumulative Mean Normalized Difference (CMND) ──
    // d'(τ) = d(τ) / ( (1/τ) Σ_{j=1}^{τ} d(j) )
    // d'(0) = 1 by convention
    final cmnd = List<double>.filled(halfW, 1.0);
    double runningSum = 0.0;
    for (int tau = 1; tau < halfW; tau++) {
      runningSum += diff[tau];
      cmnd[tau] = runningSum > 0 ? (diff[tau] * tau / runningSum) : 1.0;
    }

    // ── Step 3: Absolute threshold ──
    // Find the *first* tau where cmnd dips below the threshold.
    // This preferentially finds the fundamental, not a harmonic.
    const double yinThreshold = 0.20;
    // Lag range: sampleRate/maxHz .. sampleRate/minHz
    final minLag = (_sampleRate / 1000).round().clamp(2, halfW - 1); // ~44
    final maxLag = (_sampleRate / 70).round().clamp(minLag + 1, halfW - 1); // ~630

    int bestTau = -1;
    for (int tau = minLag; tau < maxLag; tau++) {
      if (cmnd[tau] < yinThreshold) {
        // Walk forward to the local minimum of the dip
        while (tau + 1 < maxLag && cmnd[tau + 1] < cmnd[tau]) {
          tau++;
        }
        bestTau = tau;
        break;
      }
    }

    // If no dip was found below threshold, try the global minimum in range
    if (bestTau < 0) {
      double minVal = 2.0;
      for (int tau = minLag; tau < maxLag; tau++) {
        if (cmnd[tau] < minVal) {
          minVal = cmnd[tau];
          bestTau = tau;
        }
      }
      // Only accept if the global min is reasonably low
      if (minVal > 0.45) return 0.0;
    }

    if (bestTau <= 0) return 0.0;

    // ── Step 4: Parabolic interpolation ──
    double refinedTau = bestTau.toDouble();
    if (bestTau > 1 && bestTau < halfW - 1) {
      final a = cmnd[bestTau - 1];
      final b = cmnd[bestTau];
      final c = cmnd[bestTau + 1];
      final denom = 2.0 * (2.0 * b - a - c);
      if (denom.abs() > 1e-10) {
        refinedTau = bestTau + (a - c) / denom;
      }
    }

    return _sampleRate / refinedTau;
  }


  /// Calculate RMS volume
  double _calculateVolume(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }

    return math.sqrt(sum / samples.length);
  }

  /// Calculate frequency spectrum using FFT
  List<double> _calculateSpectrum(List<double> samples) {
    if (samples.length < _windowSize) return [];

    try {
      final fft = _fft;
      if (fft == null) return [];
      final windowed = samples.take(_windowSize).toList();
      final fftResult = fft.realFft(windowed);

      // Calculate magnitude spectrum
      final spectrum = <double>[];
      for (int i = 0; i < fftResult.length ~/ 2; i++) {
        final complex = fftResult[i];
        final magnitude = math.sqrt(
          complex.x * complex.x + complex.y * complex.y,
        );
        spectrum.add(magnitude);
      }

      return spectrum;
    } catch (e) {
      debugPrint('❌ FFT calculation error: $e');
      return [];
    }
  }

  /// Detect musical notes from pitch and spectrum
  List<String> _detectNotes(double pitch, List<double> spectrum) {
    final notes = <String>[];

    if (pitch > 0) {
      final note = _frequencyToNote(pitch);
      if (note.isNotEmpty) {
        notes.add(note);
      }
    }

    // Detect harmonics
    final harmonics = _detectHarmonics(spectrum, pitch);
    for (final harmonic in harmonics) {
      final note = _frequencyToNote(harmonic);
      if (note.isNotEmpty && !notes.contains(note)) {
        notes.add(note);
      }
    }

    return notes;
  }

  /// Detect harmonics in spectrum
  List<double> _detectHarmonics(List<double> spectrum, double fundamental) {
    final harmonics = <double>[];
    if (fundamental <= 0 || spectrum.isEmpty) return harmonics;

    const maxHarmonics = 5;
    const threshold = 0.1;

    for (int h = 2; h <= maxHarmonics; h++) {
      final harmonicFreq = fundamental * h;
      if (harmonicFreq > _sampleRate / 2) break;

      final bin = (harmonicFreq * spectrum.length * 2 / _sampleRate).round();
      if (bin < spectrum.length && spectrum[bin] > threshold) {
        harmonics.add(harmonicFreq);
      }
    }

    return harmonics;
  }

  /// Convert frequency to musical note
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return '';

    const a4 = 440.0;
    final n = 12 * math.log(frequency / a4) / math.log(2);
    final noteNumber = (n + 9).round() % 12;

    const notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];

    if (noteNumber >= 0 && noteNumber < notes.length) {
      return notes[noteNumber];
    }

    return '';
  }

  /// Calculate audio quality score (0-100)
  double _calculateAudioQuality(List<double> samples, List<double> spectrum) {
    if (samples.isEmpty || spectrum.isEmpty) return 0.0;

    // Signal-to-noise ratio estimation
    final signal = _calculateVolume(samples);
    final noise = _estimateNoise(samples);
    final snr = noise > 0 ? signal / noise : signal;

    // Spectral clarity
    final spectralClarity = _calculateSpectralClarity(spectrum);

    // Combine metrics
    final qualityScore = (snr * 30 + spectralClarity * 70).clamp(0.0, 100.0);

    return qualityScore;
  }

  /// Estimate noise level in audio
  double _estimateNoise(List<double> samples) {
    if (samples.length < 100) return 0.0;

    // Use the lowest 10% of samples as noise estimate
    final sortedSamples = List<double>.from(samples);
    sortedSamples.sort();

    final noiseCount = (samples.length * 0.1).round();
    double noiseSum = 0.0;

    for (int i = 0; i < noiseCount; i++) {
      noiseSum += sortedSamples[i].abs();
    }

    return noiseSum / noiseCount;
  }

  /// Calculate spectral clarity
  double _calculateSpectralClarity(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    // Find the dominant peak
    final maxValue = spectrum.reduce(math.max);
    final avgValue = spectrum.reduce((a, b) => a + b) / spectrum.length;

    // Clarity is the ratio of peak to average
    return avgValue > 0 ? (maxValue / avgValue).clamp(0.0, 100.0) : 0.0;
  }

  /// Calculate brightness (spectral centroid)
  double _calculateBrightness(List<double> spectrum) {
    if (spectrum.isEmpty) return 0.0;

    double weightedSum = 0.0;
    double magnitudeSum = 0.0;

    for (int i = 0; i < spectrum.length; i++) {
      final freq = (i * _sampleRate) / (spectrum.length * 2);
      weightedSum += freq * spectrum[i];
      magnitudeSum += spectrum[i];
    }

    return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopRealTimeAnalysis();
    await _dataController.close();
    await _waveformController.close();
    await _spectrumController.close();
  }
}

/// Real-time audio analysis data structure
class RealtimeAudioData {
  final DateTime timestamp;
  final double pitch;
  final double volume;
  final double tempo;
  final List<double> spectrum;
  final List<String> notes;
  final List<String> sargamNotes;
  final String identifiedRaga;
  final double quality;
  final double brightness;
  final List<double> waveform;

  const RealtimeAudioData({
    required this.timestamp,
    required this.pitch,
    required this.volume,
    required this.tempo,
    required this.spectrum,
    required this.notes,
    this.sargamNotes = const [],
    this.identifiedRaga = '',
    required this.quality,
    required this.brightness,
    required this.waveform,
  });

  RealtimeAudioData copyWith({
    DateTime? timestamp,
    double? pitch,
    double? volume,
    double? tempo,
    List<double>? spectrum,
    List<String>? notes,
    List<String>? sargamNotes,
    String? identifiedRaga,
    double? quality,
    double? brightness,
    List<double>? waveform,
  }) {
    return RealtimeAudioData(
      timestamp: timestamp ?? this.timestamp,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      tempo: tempo ?? this.tempo,
      spectrum: spectrum ?? this.spectrum,
      notes: notes ?? this.notes,
      sargamNotes: sargamNotes ?? this.sargamNotes,
      identifiedRaga: identifiedRaga ?? this.identifiedRaga,
      quality: quality ?? this.quality,
      brightness: brightness ?? this.brightness,
      waveform: waveform ?? this.waveform,
    );
  }

  @override
  String toString() {
    return 'RealtimeAudioData(pitch: ${pitch.toStringAsFixed(1)} Hz, '
        'volume: ${(volume * 100).toStringAsFixed(1)}%, '
        'tempo: ${tempo.toStringAsFixed(1)} BPM, '
        'notes: $notes, quality: ${quality.toStringAsFixed(1)}%)';
  }
}
