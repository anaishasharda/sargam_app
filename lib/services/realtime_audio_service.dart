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
  late final FFT _fft;
  bool _isAnalyzing = false;

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
  static const int _bufferSize = 4096;

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

  /// Initialize the real-time audio service
  Future<void> initialize() async {
    try {
      _fft = FFT(_windowSize);

      debugPrint('✅ RealtimeAudioService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing RealtimeAudioService: $e');
      throw Exception('Failed to initialize real-time audio service: $e');
    }
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

      // Keep buffer size manageable
      if (_audioBuffer.length > _bufferSize * 2) {
        final excess = _audioBuffer.length - _bufferSize;
        _audioBuffer.removeRange(0, excess);
      }

      // Send waveform data for visualization
      if (_audioBuffer.length >= _windowSize) {
        final waveformData = _audioBuffer.sublist(
          math.max(0, _audioBuffer.length - _windowSize),
        );
        _waveformController.add(List.from(waveformData));
      }
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
      // Get the most recent audio window
      final window = _audioBuffer.sublist(
        math.max(0, _audioBuffer.length - _windowSize),
      );

      // Apply window function
      final windowedSamples = _applyHammingWindow(window);

      // Perform analysis
      final analysisData = _analyzeAudioWindow(windowedSamples);

      // Update history for tempo calculation
      _updateHistory(analysisData);

      // Calculate additional metrics
      final enhancedData = _enhanceAnalysisData(analysisData);

      // Send data to listeners
      _dataController.add(enhancedData);

      // Send spectrum data for visualization
      _spectrumController.add(enhancedData.spectrum);
    } catch (e) {
      debugPrint('❌ Error in analysis: $e');
    }
  }

  /// Analyze a single audio window
  RealtimeAudioData _analyzeAudioWindow(List<double> samples) {
    // Calculate basic metrics
    final pitch = _calculatePitch(samples);
    final volume = _calculateVolume(samples);
    final spectrum = _calculateSpectrum(samples);

    // Detect notes
    final notes = _detectNotes(pitch, spectrum);

    // Calculate quality metrics
    final quality = _calculateAudioQuality(samples, spectrum);
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
      waveform: samples.length > 100 ? samples.sublist(0, 100) : samples,
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

  /// Calculate pitch using autocorrelation
  double _calculatePitch(List<double> samples) {
    if (samples.length < 1024) return 0.0;

    final autocorr = _autocorrelation(samples.take(1024).toList());

    double maxValue = 0.0;
    int peakIndex = 0;

    // Find the highest peak after the zero lag
    for (int i = 20; i < autocorr.length ~/ 2; i++) {
      if (autocorr[i] > maxValue) {
        maxValue = autocorr[i];
        peakIndex = i;
      }
    }

    // Convert to frequency
    return peakIndex > 0 ? _sampleRate / peakIndex : 0.0;
  }

  /// Calculate autocorrelation
  List<double> _autocorrelation(List<double> samples) {
    final n = samples.length;
    final autocorr = List<double>.filled(n, 0.0);

    for (int lag = 0; lag < n; lag++) {
      double sum = 0.0;
      for (int i = 0; i < n - lag; i++) {
        sum += samples[i] * samples[i + lag];
      }
      autocorr[lag] = sum / (n - lag);
    }

    return autocorr;
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
      final windowed = samples.take(_windowSize).toList();
      final fftResult = _fft.realFft(windowed);

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
