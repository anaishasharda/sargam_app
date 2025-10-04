import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';
// import 'package:flutter_pitch_detection/flutter_pitch_detection.dart'; // Will be used in future updates
// import 'package:collection/collection.dart'; // Will be used in future updates
import '../models/audio_characteristics.dart';
import '../models/audio_feedback.dart';

class AudioAnalysisService {
  static final AudioAnalysisService _instance =
      AudioAnalysisService._internal();
  factory AudioAnalysisService() => _instance;
  AudioAnalysisService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Real-time analysis components
  bool _isAnalyzing = false;
  StreamController<AudioCharacteristics>? _realTimeController;
  Timer? _analysisTimer;
  final List<double> _audioBuffer = [];
  String? _currentRecordingPath;

  // Audio processing parameters
  static const int _sampleRate = 44100;
  static const int _windowSize = 2048;
  static const int _hopSize = 512; // Used for windowed analysis
  static const int _bufferSize = 8192;

  // FFT instance
  late final FFT _fft;

  // Cached analysis data for efficiency
  final Map<String, AudioCharacteristics> _analysisCache = {};

  bool get isAnalyzing => _isAnalyzing;

  /// Initialize the audio analysis service
  Future<void> initialize() async {
    try {
      _fft = FFT(_windowSize);
    } catch (e) {
      print('Error initializing audio analysis: $e');
    }
  }

  /// Analyze audio file with caching for efficiency
  Future<AudioCharacteristics> analyzeAudioFile(String filePath) async {
    try {
      _isAnalyzing = true;

      // Check cache first
      if (_analysisCache.containsKey(filePath)) {
        final cached = _analysisCache[filePath]!;
        print('Using cached analysis for: $filePath');
        _isAnalyzing = false;
        return cached;
      }

      // Read and process audio file
      final audioData = await _readAudioFileEfficient(filePath);
      final characteristics = await extractCharacteristicsEfficient(audioData);

      // Cache the result
      _analysisCache[filePath] = characteristics;

      _isAnalyzing = false;
      return characteristics;
    } catch (e) {
      _isAnalyzing = false;
      throw Exception('Failed to analyze audio: $e');
    }
  }

  /// Enhanced audio comparison with better accuracy calculations
  Future<AudioFeedback> compareAudio(
    AudioCharacteristics reference,
    AudioCharacteristics user,
    List<String> expectedNotes,
  ) async {
    try {
      // Enhanced pitch accuracy using frequency domain analysis
      final pitchAccuracy = _calculateEnhancedPitchAccuracy(reference, user);

      // Enhanced tempo accuracy with beat tracking
      final tempoAccuracy = _calculateEnhancedTempoAccuracy(reference, user);

      // Enhanced rhythm accuracy using cross-correlation
      final rhythmAccuracy = _calculateEnhancedRhythmAccuracy(reference, user);

      // Spectral similarity for timbre matching
      final timbreAccuracy = _calculateTimbreAccuracy(reference, user);

      // Overall accuracy with weighted components
      final overallAccuracy = _calculateWeightedAccuracy(
        pitchAccuracy,
        tempoAccuracy,
        rhythmAccuracy,
        timbreAccuracy,
      );

      // Enhanced note detection and missed notes analysis
      final missedNotes = _findMissedNotesEnhanced(
        reference,
        user,
        expectedNotes,
      );

      // Generate contextual suggestions for Indian music
      final suggestions = _generateIndianMusicSuggestions(
        pitchAccuracy,
        tempoAccuracy,
        rhythmAccuracy,
        timbreAccuracy,
        missedNotes,
      );

      final overallFeedback = _generateDetailedFeedback(
        overallAccuracy,
        pitchAccuracy,
        tempoAccuracy,
        rhythmAccuracy,
        missedNotes,
      );

      return AudioFeedback(
        pitchAccuracy: pitchAccuracy,
        tempoAccuracy: tempoAccuracy,
        rhythmAccuracy: rhythmAccuracy,
        overallAccuracy: overallAccuracy,
        missedNotes: missedNotes,
        suggestions: suggestions,
        overallFeedback: overallFeedback,
        characteristics: user,
      );
    } catch (e) {
      throw Exception('Failed to compare audio: $e');
    }
  }

  /// Start efficient real-time audio analysis
  Stream<AudioCharacteristics> startRealTimeAnalysis() {
    if (_isAnalyzing) {
      throw Exception('Analysis already in progress');
    }

    _isAnalyzing = true;
    _audioBuffer.clear();

    _realTimeController = StreamController<AudioCharacteristics>();

    // Start the real-time analysis loop
    _startRealTimeAnalysisLoop();

    return _realTimeController!.stream;
  }

  /// Start real-time analysis with recording
  Future<Stream<AudioCharacteristics>>
  startRealTimeAnalysisWithRecording() async {
    if (_isAnalyzing) {
      throw Exception('Analysis already in progress');
    }

    _isAnalyzing = true;
    _audioBuffer.clear();

    // Start recording to a temporary file
    final directory = Directory.systemTemp;
    _currentRecordingPath =
        '${directory.path}/realtime_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav, // Use WAV for better real-time processing
        bitRate: 128000,
        sampleRate: _sampleRate,
        numChannels: 1, // Mono for efficiency
      ),
      path: _currentRecordingPath!,
    );

    _realTimeController = StreamController<AudioCharacteristics>();

    // Start the real-time analysis loop with recording
    _startRealTimeAnalysisWithRecordingLoop();

    return _realTimeController!.stream;
  }

  /// Efficient real-time analysis loop
  void _startRealTimeAnalysisLoop() {
    const analysisInterval = Duration(milliseconds: 100); // Faster analysis

    _analysisTimer = Timer.periodic(analysisInterval, (timer) async {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }

      try {
        // Generate synthetic audio data for testing (replace with actual microphone input)
        final syntheticData = _generateTestAudioData();
        _audioBuffer.addAll(syntheticData);

        // Keep buffer size manageable
        if (_audioBuffer.length > _bufferSize) {
          _audioBuffer.removeRange(0, _audioBuffer.length - _bufferSize);
        }

        if (_audioBuffer.length >= _windowSize) {
          final characteristics = await extractCharacteristicsRealTime(
            _audioBuffer,
          );
          _realTimeController?.add(characteristics);
        }
      } catch (e) {
        print('Real-time analysis error: $e');
      }
    });
  }

  /// Real-time analysis loop with recording
  void _startRealTimeAnalysisWithRecordingLoop() {
    const analysisInterval = Duration(milliseconds: 150);

    _analysisTimer = Timer.periodic(analysisInterval, (timer) async {
      if (!_isAnalyzing) {
        timer.cancel();
        return;
      }

      try {
        // Read new audio data from the recording
        final newData = await _readRecentAudioData();
        if (newData.isNotEmpty) {
          _audioBuffer.addAll(newData);

          // Keep buffer size manageable
          if (_audioBuffer.length > _bufferSize) {
            _audioBuffer.removeRange(0, _audioBuffer.length - _bufferSize);
          }

          if (_audioBuffer.length >= _windowSize) {
            final characteristics = await extractCharacteristicsRealTime(
              _audioBuffer,
            );
            _realTimeController?.add(characteristics);
          }
        }
      } catch (e) {
        print('Real-time recording analysis error: $e');
      }
    });
  }

  /// Stop real-time analysis
  void stopRealTimeAnalysis() {
    _isAnalyzing = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _realTimeController?.close();
    _realTimeController = null;
    _audioBuffer.clear();
  }

  /// Stop real-time analysis with recording
  Future<void> stopRealTimeAnalysisWithRecording() async {
    _isAnalyzing = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;

    try {
      await _audioRecorder.stop();
    } catch (e) {
      print('Error stopping recorder: $e');
    }

    _realTimeController?.close();
    _realTimeController = null;
    _audioBuffer.clear();
    _currentRecordingPath = null;
  }

  /// Efficient audio file reading
  Future<List<double>> _readAudioFileEfficient(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      return _convertBytesToSamplesEfficient(bytes);
    } catch (e) {
      throw Exception('Failed to read audio file: $e');
    }
  }

  /// More efficient byte to sample conversion
  List<double> _convertBytesToSamplesEfficient(Uint8List bytes) {
    final samples = <double>[];

    // Handle WAV format more efficiently
    if (bytes.length < 44) return samples; // Invalid WAV header

    // Skip WAV header (44 bytes) and convert 16-bit samples
    for (int i = 44; i < bytes.length - 1; i += 2) {
      final sample = (bytes[i] | (bytes[i + 1] << 8)).toSigned(16);
      samples.add(sample / 32768.0); // Normalize to [-1, 1]
    }

    return samples;
  }

  /// Enhanced characteristic extraction using FFT (public for testing)
  Future<AudioCharacteristics> extractCharacteristicsEfficient(
    List<double> samples,
  ) async {
    if (samples.isEmpty) {
      return _getEmptyCharacteristics();
    }

    // Efficient pitch detection using the dedicated library
    final pitch = await _calculatePitchEfficient(samples);

    // Enhanced tempo calculation using onset detection
    final tempo = _calculateTempoEnhanced(samples);

    // Rhythm pattern using beat tracking
    final rhythm = _calculateRhythmEnhanced(samples);

    // Note detection using pitch and harmonic analysis
    final notes = _detectNotesEnhanced(samples, pitch);

    // RMS volume calculation
    final volume = _calculateVolumeEfficient(samples);

    // FFT spectrum analysis
    final spectrum = _calculateSpectrumFFT(samples);

    final duration = samples.length / _sampleRate;

    return AudioCharacteristics(
      pitch: pitch,
      tempo: tempo,
      rhythm: rhythm,
      notes: notes,
      volume: volume,
      spectrum: spectrum,
      duration: duration,
    );
  }

  /// Real-time optimized characteristic extraction (public for testing)
  Future<AudioCharacteristics> extractCharacteristicsRealTime(
    List<double> samples,
  ) async {
    if (samples.length < _windowSize) {
      return _getEmptyCharacteristics();
    }

    // Use only the most recent window for real-time analysis
    final window = samples.sublist(samples.length - _windowSize);

    // Apply window function for better frequency analysis
    final windowedSamples = _applyHammingWindow(window);

    final pitch = await _calculatePitchEfficient(windowedSamples);
    final volume = _calculateVolumeEfficient(windowedSamples);
    final spectrum = _calculateSpectrumFFT(windowedSamples);
    final notes = pitch > 0 ? [_frequencyToNote(pitch)] : <String>[];

    return AudioCharacteristics(
      pitch: pitch,
      tempo: 0.0, // Skip tempo calculation for real-time
      rhythm: [],
      notes: notes.where((note) => note.isNotEmpty).toList(),
      volume: volume,
      spectrum: spectrum,
      duration: window.length / _sampleRate,
    );
  }

  /// Apply Hamming window for better frequency analysis
  List<double> _applyHammingWindow(List<double> samples) {
    final windowed = <double>[];
    final n = samples.length;

    for (int i = 0; i < n; i++) {
      final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (n - 1));
      windowed.add(samples[i] * window);
    }

    return windowed;
  }

  /// Efficient pitch calculation using autocorrelation
  Future<double> _calculatePitchEfficient(List<double> samples) async {
    try {
      if (samples.length < _windowSize) return 0.0;

      // TODO: Use flutter_pitch_detection library when properly configured
      // For now, use autocorrelation method
      return _calculatePitchAutocorrelation(samples);
    } catch (e) {
      // Fallback to autocorrelation if library fails
      return _calculatePitchAutocorrelation(samples);
    }
  }

  /// Fallback pitch calculation using autocorrelation
  double _calculatePitchAutocorrelation(List<double> samples) {
    if (samples.length < _windowSize) return 0.0;

    final window = samples.take(_windowSize).toList();
    final autocorr = _autocorrelation(window);

    double maxValue = 0.0;
    int peakIndex = 0;

    // Find the highest peak after the zero lag
    for (int i = 20; i < autocorr.length ~/ 2; i++) {
      if (autocorr[i] > maxValue) {
        maxValue = autocorr[i];
        peakIndex = i;
      }
    }

    return peakIndex > 0 ? _sampleRate / peakIndex : 0.0;
  }

  /// Enhanced tempo calculation using onset detection
  double _calculateTempoEnhanced(List<double> samples) {
    final onsets = _detectOnsetsThorough(samples);

    if (onsets.length < 3) return 0.0;

    // Calculate inter-onset intervals
    final intervals = <double>[];
    for (int i = 1; i < onsets.length; i++) {
      intervals.add(onsets[i] - onsets[i - 1]);
    }

    // Find the most common interval using histogram
    final tempo = _estimateTempoFromIntervals(intervals);
    return tempo;
  }

  /// Enhanced rhythm calculation
  List<double> _calculateRhythmEnhanced(List<double> samples) {
    final onsets = _detectOnsetsThorough(samples);
    final rhythm = <double>[];

    for (int i = 1; i < onsets.length; i++) {
      rhythm.add(onsets[i] - onsets[i - 1]);
    }

    return rhythm;
  }

  /// Thorough onset detection
  List<double> _detectOnsetsThorough(List<double> samples) {
    final onsets = <double>[];
    const windowSize = 1024;
    final hopSize = _hopSize; // Use the class constant
    const threshold = 0.02;

    for (int i = 0; i < samples.length - windowSize; i += hopSize) {
      final window = samples.sublist(i, i + windowSize);
      final energy = _calculateEnergy(window);
      final spectralFlux = _calculateSpectralFlux(window);

      if (energy > threshold && spectralFlux > threshold) {
        onsets.add(i / _sampleRate);
      }
    }

    return onsets;
  }

  /// Calculate spectral flux for onset detection
  double _calculateSpectralFlux(List<double> samples) {
    final spectrum = _calculateSpectrumFFT(samples);
    double flux = 0.0;

    for (int i = 1; i < spectrum.length; i++) {
      final diff = spectrum[i] - spectrum[i - 1];
      if (diff > 0) flux += diff;
    }

    return flux;
  }

  /// Estimate tempo from intervals
  double _estimateTempoFromIntervals(List<double> intervals) {
    if (intervals.isEmpty) return 0.0;

    // Create histogram of intervals
    final histogram = <double, int>{};
    for (final interval in intervals) {
      final rounded = (interval * 10).round() / 10.0; // Round to 0.1s
      histogram[rounded] = (histogram[rounded] ?? 0) + 1;
    }

    // Find most common interval
    final mostCommon = histogram.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return mostCommon > 0 ? 60.0 / mostCommon : 0.0;
  }

  /// Enhanced note detection with harmonic analysis
  List<String> _detectNotesEnhanced(
    List<double> samples,
    double fundamentalPitch,
  ) {
    final notes = <String>[];

    if (fundamentalPitch <= 0) return notes;

    // Add fundamental note
    final fundamentalNote = _frequencyToNote(fundamentalPitch);
    if (fundamentalNote.isNotEmpty) {
      notes.add(fundamentalNote);
    }

    // Detect harmonics for richer note detection
    final spectrum = _calculateSpectrumFFT(samples);
    final harmonics = _detectHarmonics(spectrum, fundamentalPitch);

    for (final harmonic in harmonics) {
      final note = _frequencyToNote(harmonic);
      if (note.isNotEmpty && !notes.contains(note)) {
        notes.add(note);
      }
    }

    return notes;
  }

  /// Detect harmonics in the spectrum
  List<double> _detectHarmonics(List<double> spectrum, double fundamental) {
    final harmonics = <double>[];
    const maxHarmonics = 5;

    for (int h = 2; h <= maxHarmonics; h++) {
      final harmonicFreq = fundamental * h;
      if (harmonicFreq > _sampleRate / 2) break;

      final bin = (harmonicFreq * spectrum.length * 2 / _sampleRate).round();
      if (bin < spectrum.length && spectrum[bin] > 0.01) {
        harmonics.add(harmonicFreq);
      }
    }

    return harmonics;
  }

  /// Efficient volume calculation
  double _calculateVolumeEfficient(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }

    return math.sqrt(sum / samples.length);
  }

  /// FFT-based spectrum calculation
  List<double> _calculateSpectrumFFT(List<double> samples) {
    if (samples.length < _windowSize) return [];

    try {
      final window = samples.take(_windowSize).toList();
      final windowed = _applyHammingWindow(window);

      // Convert to complex numbers for FFT
      final complexSamples = windowed
          .map((sample) => Complex(sample, 0.0))
          .toList();

      // Pad to FFT size if necessary
      while (complexSamples.length < _windowSize) {
        complexSamples.add(Complex(0.0, 0.0));
      }

      final fftResult = _fft.realFft(windowed.cast<double>());

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
      print('FFT calculation error: $e');
      return _calculateSpectrumFallback(samples);
    }
  }

  /// Fallback spectrum calculation without FFT
  List<double> _calculateSpectrumFallback(List<double> samples) {
    final spectrum = <double>[];
    final window = samples.take(_windowSize).toList();

    for (int i = 0; i < window.length ~/ 2; i++) {
      double magnitude = 0.0;
      for (int j = 0; j < window.length; j++) {
        magnitude += window[j] * math.cos(2 * math.pi * i * j / window.length);
      }
      spectrum.add(magnitude.abs());
    }

    return spectrum;
  }

  /// Enhanced pitch accuracy calculation
  double _calculateEnhancedPitchAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    if (reference.pitch == 0 || user.pitch == 0) return 0.0;

    // Calculate cents difference (more musical than frequency ratio)
    final centsError =
        1200 * (math.log(user.pitch / reference.pitch) / math.log(2));
    final accuracy = math.max(0.0, 100.0 - centsError.abs() / 50.0 * 100.0);

    return math.min(100.0, accuracy);
  }

  /// Enhanced tempo accuracy calculation
  double _calculateEnhancedTempoAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    if (reference.tempo == 0 || user.tempo == 0) return 0.0;

    final tempoRatio = user.tempo / reference.tempo;
    final accuracy = 100.0 * (1.0 - (tempoRatio - 1.0).abs());

    return math.max(0.0, math.min(100.0, accuracy));
  }

  /// Enhanced rhythm accuracy using cross-correlation
  double _calculateEnhancedRhythmAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    if (reference.rhythm.isEmpty || user.rhythm.isEmpty) return 0.0;

    final correlation = _crossCorrelation(reference.rhythm, user.rhythm);
    return correlation * 100.0;
  }

  /// Calculate timbre accuracy using spectral features
  double _calculateTimbreAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    if (reference.spectrum.isEmpty || user.spectrum.isEmpty) return 0.0;

    // Calculate spectral centroid similarity
    final refCentroid = reference.spectralCentroid;
    final userCentroid = user.spectralCentroid;

    if (refCentroid == 0 || userCentroid == 0) return 0.0;

    final centroidRatio = userCentroid / refCentroid;
    final centroidAccuracy = 100.0 * (1.0 - (centroidRatio - 1.0).abs());

    return math.max(0.0, math.min(100.0, centroidAccuracy));
  }

  /// Calculate weighted overall accuracy
  double _calculateWeightedAccuracy(
    double pitch,
    double tempo,
    double rhythm,
    double timbre,
  ) {
    // Weights for Indian music: pitch is most important, then rhythm, tempo, and timbre
    const pitchWeight = 0.4;
    const rhythmWeight = 0.3;
    const tempoWeight = 0.2;
    const timbreWeight = 0.1;

    return (pitch * pitchWeight +
        rhythm * rhythmWeight +
        tempo * tempoWeight +
        timbre * timbreWeight);
  }

  /// Enhanced missed notes detection
  List<String> _findMissedNotesEnhanced(
    AudioCharacteristics reference,
    AudioCharacteristics user,
    List<String> expectedNotes,
  ) {
    final missedNotes = <String>[];

    // Check expected notes against user performance
    for (final expectedNote in expectedNotes) {
      if (!user.notes.contains(expectedNote)) {
        missedNotes.add(expectedNote);
      }
    }

    // Also check reference notes
    for (final refNote in reference.notes) {
      if (!user.notes.contains(refNote) && !missedNotes.contains(refNote)) {
        missedNotes.add(refNote);
      }
    }

    return missedNotes;
  }

  /// Generate suggestions specific to Indian music
  List<String> _generateIndianMusicSuggestions(
    double pitchAccuracy,
    double tempoAccuracy,
    double rhythmAccuracy,
    double timbreAccuracy,
    List<String> missedNotes,
  ) {
    final suggestions = <String>[];

    if (pitchAccuracy < 70) {
      suggestions.add(
        'Practice swara (note) accuracy. Use a tanpura for reference pitch.',
      );
      suggestions.add('Focus on melakartha scales to improve pitch precision.');
    }

    if (rhythmAccuracy < 70) {
      suggestions.add(
        'Practice with a tabla or metronome to improve taal (rhythm).',
      );
      suggestions.add(
        'Work on different taals like Teentaal, Ektaal, or Rupak.',
      );
    }

    if (tempoAccuracy < 70) {
      suggestions.add(
        'Practice at slower laya (tempo) first, then gradually increase.',
      );
      suggestions.add(
        'Use a tabla machine or metronome for consistent tempo practice.',
      );
    }

    if (timbreAccuracy < 70) {
      suggestions.add(
        'Focus on voice quality and breath control for better tone.',
      );
      suggestions.add(
        'Practice alankar (vocal exercises) for tonal improvement.',
      );
    }

    if (missedNotes.isNotEmpty) {
      suggestions.add('Practice the missed swaras: ${missedNotes.join(', ')}');
      suggestions.add(
        'Work on gamaka (ornamentation) for smoother note transitions.',
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        'Excellent! Continue practicing to maintain consistency.',
      );
      suggestions.add('Try exploring more complex ragas and taals.');
    }

    return suggestions;
  }

  /// Generate detailed feedback
  String _generateDetailedFeedback(
    double overall,
    double pitch,
    double tempo,
    double rhythm,
    List<String> missedNotes,
  ) {
    final buffer = StringBuffer();

    if (overall >= 90) {
      buffer.write('Outstanding performance! ');
    } else if (overall >= 80) {
      buffer.write('Very good performance! ');
    } else if (overall >= 70) {
      buffer.write('Good effort! ');
    } else {
      buffer.write('Keep practicing! ');
    }

    // Add specific feedback
    if (pitch < 70) buffer.write('Focus on pitch accuracy. ');
    if (tempo < 70) buffer.write('Work on tempo consistency. ');
    if (rhythm < 70) buffer.write('Practice rhythmic precision. ');

    if (missedNotes.isNotEmpty) {
      buffer.write(
        'Review the missed notes: ${missedNotes.take(3).join(', ')}.',
      );
    }

    return buffer.toString();
  }

  /// Utility methods

  AudioCharacteristics _getEmptyCharacteristics() {
    return const AudioCharacteristics(
      pitch: 0.0,
      tempo: 0.0,
      rhythm: [],
      notes: [],
      volume: 0.0,
      spectrum: [],
      duration: 0.0,
    );
  }

  List<double> _generateTestAudioData() {
    // Generate a sine wave for testing real-time analysis
    final data = <double>[];
    const frequency = 440.0; // A4 note
    const amplitude = 0.5;

    for (int i = 0; i < 256; i++) {
      final sample =
          amplitude * math.sin(2 * math.pi * frequency * i / _sampleRate);
      data.add(sample);
    }

    return data;
  }

  Future<List<double>> _readRecentAudioData() async {
    // This is a placeholder for reading recent audio data from the recording
    // In a real implementation, you would read the most recent data from the recording file
    try {
      if (_currentRecordingPath == null) return [];

      final file = File(_currentRecordingPath!);
      if (!await file.exists()) return [];

      final bytes = await file.readAsBytes();
      if (bytes.length < 1024) return []; // Not enough data yet

      // Read only the most recent data (last 1KB)
      final recentBytes = bytes.sublist(math.max(0, bytes.length - 1024));
      return _convertBytesToSamplesEfficient(Uint8List.fromList(recentBytes));
    } catch (e) {
      return [];
    }
  }

  double _calculateEnergy(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }

    return sum / samples.length;
  }

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

  double _crossCorrelation(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;

    final minLength = math.min(a.length, b.length);
    double correlation = 0.0;

    for (int i = 0; i < minLength; i++) {
      correlation += a[i] * b[i];
    }

    return correlation / minLength;
  }

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

  /// Clear analysis cache to free memory
  void clearCache() {
    _analysisCache.clear();
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isAnalyzing = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _realTimeController?.close();
    _realTimeController = null;
    _audioBuffer.clear();
    _analysisCache.clear();
    _currentRecordingPath = null;

    try {
      await _audioRecorder.dispose();
      await _audioPlayer.dispose();
    } catch (e) {
      print('Error disposing audio resources: $e');
    }
  }
}

/// Complex number class for FFT calculations
class Complex {
  final double real;
  final double imaginary;

  const Complex(this.real, this.imaginary);

  Complex operator +(Complex other) {
    return Complex(real + other.real, imaginary + other.imaginary);
  }

  Complex operator -(Complex other) {
    return Complex(real - other.real, imaginary - other.imaginary);
  }

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imaginary * other.imaginary,
      real * other.imaginary + imaginary * other.real,
    );
  }

  double get magnitude => math.sqrt(real * real + imaginary * imaginary);
}
