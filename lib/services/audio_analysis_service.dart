// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';
// import 'package:flutter_pitch_detection/flutter_pitch_detection.dart'; // Will be used in future updates
// import 'package:collection/collection.dart'; // Will be used in future updates
import '../models/audio_characteristics.dart';
import '../models/audio_feedback.dart';
import 'normalized_compare.dart';
import 'sa_pitch.dart';

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

      print('Analyzing audio file: $filePath');

      // Read and process audio file
      final audioData = await _readAudioFileEfficient(filePath);

      if (audioData.isEmpty) {
        print('Warning: No audio data extracted from $filePath');
        _isAnalyzing = false;
        return _getEmptyCharacteristics();
      }

      print('Audio data extracted: ${audioData.length} samples');

      final characteristics = await extractCharacteristicsEfficient(audioData);

      // Cache the result
      _analysisCache[filePath] = characteristics;

      print(
        'Analysis complete - Pitch: ${characteristics.pitch.toStringAsFixed(2)} Hz, Notes: ${characteristics.notes}',
      );

      _isAnalyzing = false;
      return characteristics;
    } catch (e) {
      print('Error analyzing audio file: $e');
      _isAnalyzing = false;
      throw Exception('Failed to analyze audio: $e');
    }
  }

  /// Enhanced audio comparison with better accuracy calculations
  Future<AudioFeedback> compareAudio(
    AudioCharacteristics reference,
    AudioCharacteristics user,
    List<String> expectedNotes, {
    double? userSaHz,
    double? referenceSaHz,
    RagaSwaraTable? table,
  }) async {
    try {
      print('\n=== Audio Comparison ===');
      print(
        'Reference - Pitch: ${reference.pitch.toStringAsFixed(2)} Hz, Notes: ${reference.notes}, Volume: ${reference.volume.toStringAsFixed(3)}',
      );
      print(
        'User - Pitch: ${user.pitch.toStringAsFixed(2)} Hz, Notes: ${user.notes}, Volume: ${user.volume.toStringAsFixed(3)}',
      );
      print('Expected Notes: $expectedNotes');

      // If the user produced no audible signal (silence or background noise only)
      // return near-zero accuracy immediately instead of inflated "neutral" scores.
      const double silenceVolumeThreshold = 0.01;
      if (user.volume < silenceVolumeThreshold && user.pitch == 0) {
        print('User audio is silent – returning zero accuracy.');
        return AudioFeedback(
          pitchAccuracy: 0.0,
          tempoAccuracy: 0.0,
          rhythmAccuracy: 0.0,
          overallAccuracy: 0.0,
          missedNotes: List<String>.from(expectedNotes),
          suggestions: [
            'No singing detected. Please sing clearly into the microphone.',
          ],
          overallFeedback:
              'No singing detected. Make sure your microphone is working and try again.',
          characteristics: user,
        );
      }

      // Enhanced pitch accuracy using frequency domain analysis.
      // Plan 1.8: when both Sa values are known and both pitch contours
      // exist, score in Sa-normalized cents space (normalized_compare.dart)
      // so a student is not punished for singing at a different Sa than the
      // reference. In every other case the legacy calculation runs
      // unchanged.
      final double pitchAccuracy;
      if (userSaHz != null &&
          userSaHz > 0 &&
          referenceSaHz != null &&
          referenceSaHz > 0 &&
          reference.pitchTrajectory.isNotEmpty &&
          user.pitchTrajectory.isNotEmpty) {
        pitchAccuracy = compareNormalized(
          referenceTrajectoryHz: reference.pitchTrajectory,
          referenceSaHz: referenceSaHz,
          userTrajectoryHz: user.pitchTrajectory,
          userSaHz: userSaHz,
        ).trajectoryScore;
        print(
          'Pitch scoring: Sa-normalized (user Sa $userSaHz Hz, reference Sa $referenceSaHz Hz)',
        );
      } else {
        pitchAccuracy = _calculateEnhancedPitchAccuracy(reference, user);
      }
      print('Pitch Accuracy: ${pitchAccuracy.toStringAsFixed(2)}%');

      // Enhanced tempo accuracy with beat tracking
      final tempoAccuracy = _calculateEnhancedTempoAccuracy(reference, user);
      print('Tempo Accuracy: ${tempoAccuracy.toStringAsFixed(2)}%');

      // Enhanced rhythm accuracy using cross-correlation
      final rhythmAccuracy = _calculateEnhancedRhythmAccuracy(reference, user);
      print('Rhythm Accuracy: ${rhythmAccuracy.toStringAsFixed(2)}%');

      // Spectral similarity for timbre matching
      final timbreAccuracy = _calculateTimbreAccuracy(reference, user);
      print('Timbre Accuracy: ${timbreAccuracy.toStringAsFixed(2)}%');

      // Overall accuracy with weighted components
      final overallAccuracy = _calculateWeightedAccuracy(
        pitchAccuracy,
        tempoAccuracy,
        rhythmAccuracy,
        timbreAccuracy,
      );
      print('Overall Accuracy: ${overallAccuracy.toStringAsFixed(2)}%');

      // Enhanced note detection and missed notes analysis
      final missedNotes = _findMissedNotesEnhanced(
        reference,
        user,
        expectedNotes,
      );
      print('Missed Notes: $missedNotes');
      print('======================\n');

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

      // 1.2: when scoring ran Sa-normalized with a raga table, diagnose
      // each swara from the user contour and rebuild missed notes from
      // the raga-constrained sung sets (non-raga notes impossible).
      var swaraDiagnosis = const <SwaraDiagnosis>[];
      List<String>? constrainedMissed;
      // The diagnosis itself needs only the student's Sa and contour;
      // the reference contributes only extra missed-note candidates
      // when its Sa and contour are available.
      if (table != null &&
          userSaHz != null &&
          userSaHz > 0 &&
          user.pitchTrajectory.isNotEmpty) {
        swaraDiagnosis =
            diagnoseSwara(user.pitchTrajectory, userSaHz, table);
        print('Swara diagnosis: ${swaraDiagnosis.join(', ')}');
        final sungUser =
            constrainedSungNotes(user.pitchTrajectory, userSaHz, table);
        final missedSet = <String>{};
        for (final n in expectedNotes) {
          if (!sungUser.contains(n)) missedSet.add(n);
        }
        if (referenceSaHz != null &&
            referenceSaHz > 0 &&
            reference.pitchTrajectory.isNotEmpty) {
          final sungRef = constrainedSungNotes(
              reference.pitchTrajectory, referenceSaHz, table);
          for (final n in sungRef) {
            if (!sungUser.contains(n)) missedSet.add(n);
          }
        }
        constrainedMissed = missedSet.toList();
      }

      return AudioFeedback(
        pitchAccuracy: pitchAccuracy,
        tempoAccuracy: tempoAccuracy,
        rhythmAccuracy: rhythmAccuracy,
        overallAccuracy: overallAccuracy,
        missedNotes: constrainedMissed ?? missedNotes,
        suggestions: suggestions,
        overallFeedback: overallFeedback,
        characteristics: user,
        swaraDiagnosis: swaraDiagnosis,
      );
    } catch (e) {
      print('Error in compareAudio: $e');
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

    // Handle WAV format
    if (bytes.length < 44) {
      print('WAV file too small: ${bytes.length} bytes');
      return samples;
    }

    final header = String.fromCharCodes(bytes.take(4));
    if (header != 'RIFF') {
      print('Not a valid WAV file (no RIFF header)');
      return samples;
    }

    // Find the 'fmt ' and 'data' chunks
    int offset = 12; // Start after 'RIFF' + size + 'WAVE'
    int dataStart = -1;
    int dataSize = 0;

    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize =
          bytes[offset + 4] |
          (bytes[offset + 5] << 8) |
          (bytes[offset + 6] << 16) |
          (bytes[offset + 7] << 24);

      if (chunkId == 'data') {
        dataStart = offset + 8;
        dataSize = chunkSize;
        print('Found data chunk at offset $dataStart, size: $dataSize bytes');
        break; // Found data, we can stop searching chunks
      }
      offset += 8 + chunkSize;
    }

    if (dataStart == -1 || dataStart >= bytes.length) {
      print('Could not find data chunk in WAV file. Fallback to offset 44.');
      // Fallback to standard 44-byte header
      dataStart = 44;
      dataSize = bytes.length - 44;
    }

    // Ensure we don't read past the end of the file
    int endByte = dataStart + dataSize;
    if (endByte > bytes.length) {
      endByte = bytes.length;
    }
    // Make sure we end on an even byte index for 16-bit samples
    if ((endByte - dataStart) % 2 != 0) {
      endByte -= 1;
    }

    // Determine how many bytes to skip to read mono safely.
    // Assuming 16-bit (2 bytes per sample). If stereo, byteRate would be sampleRate * 4.
    // However, record package usually records mono. We will read every 2 bytes as a sample.
    int bytesPerSample = 2;

    // Convert 16-bit PCM samples
    for (int i = dataStart; i < endByte; i += bytesPerSample) {
      int sample = bytes[i] | (bytes[i + 1] << 8);
      // Convert to signed 16-bit
      if (sample >= 32768) {
        sample -= 65536;
      }
      samples.add(sample / 32768.0); // Normalize to [-1, 1]
    }

    print('Extracted ${samples.length} samples from WAV file');
    if (samples.isNotEmpty) {
      // Calculate some stats for debugging
      double maxAbs = 0;
      for (final s in samples) {
        if (s.abs() > maxAbs) maxAbs = s.abs();
      }
      print('Max sample amplitude: $maxAbs');
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

    print('Extracting characteristics from ${samples.length} samples');

    // Analyze multiple windows for better accuracy
    final pitches = <double>[];
    final volumes = <double>[];
    final allNotes = <String>{};
    int windowsProcessed = 0;
    int windowsWithAudio = 0;

    // Process audio in overlapping windows
    final hopSize = _windowSize ~/ 2; // 50% overlap
    for (int i = 0; i < samples.length - _windowSize; i += hopSize) {
      final window = samples.sublist(
        i,
        math.min(i + _windowSize, samples.length),
      );
      windowsProcessed++;

      final windowPitch = await _calculatePitchEfficient(window);
      final windowVolume = _calculateVolumeEfficient(window);

      // Lower threshold for mobile recordings (0.005 instead of 0.01)
      if (windowVolume > 0.02 && windowPitch > 0) {
        // 0.02 RMS is a meaningful threshold – filters out background mic noise
        windowsWithAudio++;
        pitches.add(windowPitch);
        volumes.add(windowVolume);

        // Detect notes in this window
        final note = _frequencyToNote(windowPitch);
        if (note.isNotEmpty) {
          allNotes.add(note);
        }
      }
    }

    print(
      'Windows processed: $windowsProcessed, with audio: $windowsWithAudio',
    );

    // Calculate average pitch (weighted by volume)
    double avgPitch = 0.0;
    if (pitches.isNotEmpty) {
      double totalWeight = volumes.fold(0.0, (sum, v) => sum + v);
      if (totalWeight > 0) {
        for (int i = 0; i < pitches.length; i++) {
          avgPitch += pitches[i] * volumes[i] / totalWeight;
        }
      } else {
        avgPitch = pitches.reduce((a, b) => a + b) / pitches.length;
      }
    }

    print(
      'Detected average pitch: ${avgPitch.toStringAsFixed(2)} Hz from ${pitches.length} windows',
    );
    print('Detected notes: ${allNotes.toList()}');

    // Enhanced tempo calculation using onset detection
    final tempo = _calculateTempoEnhanced(samples);

    // Rhythm pattern using beat tracking
    final rhythm = _calculateRhythmEnhanced(samples);

    // Use detected notes from windowed analysis
    final notes = allNotes.toList();

    // Overall RMS volume calculation
    final volume = _calculateVolumeEfficient(samples);

    // FFT spectrum analysis on representative window
    final midPoint = samples.length ~/ 2;
    final spectrumWindow = samples.sublist(
      math.max(0, midPoint - _windowSize ~/ 2),
      math.min(samples.length, midPoint + _windowSize ~/ 2),
    );
    final spectrum = _calculateSpectrumFFT(spectrumWindow);

    final duration = samples.length / _sampleRate;

    return AudioCharacteristics(
      pitch: avgPitch,
      tempo: tempo,
      rhythm: rhythm,
      notes: notes,
      volume: volume,
      spectrum: spectrum,
      duration: duration,
      pitchTrajectory: pitches,
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
      pitchTrajectory: pitch > 0 ? [pitch] : [],
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

    // Calculate RMS to check if there's enough signal
    final rms = _calculateVolumeEfficient(window);
    // Must have a meaningful signal before attempting pitch detection.
    // 0.01 filters background mic noise; raise if false positives persist.
    if (rms < 0.01) {
      return 0.0; // Too quiet, no pitch
    }

    final autocorr = _autocorrelation(window);

    // Normalize autocorrelation by the zero-lag value
    final normalizer = autocorr[0] > 0 ? autocorr[0] : 1.0;

    double maxValue = 0.0;
    int peakIndex = 0;

    // Find the highest peak after the zero lag
    // Pitch range: 80Hz (low voice) to 1000Hz (high voice)
    // Corresponds to samples: sampleRate/1000 to sampleRate/80
    final minLag = (_sampleRate / 1000).round(); // ~44 samples for 1000Hz
    final maxLag = (_sampleRate / 80).round(); // ~551 samples for 80Hz

    for (int i = minLag; i < math.min(maxLag, autocorr.length ~/ 2); i++) {
      final normalizedValue = autocorr[i] / normalizer;
      if (normalizedValue > maxValue) {
        maxValue = normalizedValue;
        peakIndex = i;
      }
    }

    // Confidence threshold: 0.4 means the autocorrelation peak must be at least
    // 40% of the zero-lag energy. Background noise rarely crosses this.
    if (maxValue < 0.4) {
      return 0.0;
    }

    final detectedPitch = peakIndex > 0 ? _sampleRate / peakIndex : 0.0;
    return detectedPitch;
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

  /// Enhanced pitch accuracy calculation based on finding correct notes and trajectory
  double _calculateEnhancedPitchAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    // If user has no detected pitch, they weren't singing – score is 0, not a neutral fallback.
    if (user.pitch == 0) return 0.0;
    if (reference.pitch == 0) return 30.0;

    // 1. Point-by-point Pitch Trajectory Comparison
    double trajectoryScore = 0.0;
    if (reference.pitchTrajectory.isNotEmpty &&
        user.pitchTrajectory.isNotEmpty) {
      final refTraj = reference.pitchTrajectory;
      final userTraj = user.pitchTrajectory;

      int comparisons = math.min(refTraj.length, userTraj.length);
      double totalDeviation = 0.0;
      int validComparisons = 0;

      for (int i = 0; i < comparisons; i++) {
        int refIndex = (i * refTraj.length / comparisons).floor();
        double rPitch = refTraj[refIndex];
        double uPitch = userTraj[i];

        if (rPitch > 0 && uPitch > 0) {
          validComparisons++;
          double deviation = (uPitch / rPitch - 1.0).abs();

          double octaveDiff = (math.log(uPitch / rPitch) / math.log(2)).abs();
          double nearestOctave = octaveDiff.roundToDouble();
          double octaveDeviation = (octaveDiff - nearestOctave).abs();

          if (deviation > 0.1) {
            totalDeviation += octaveDeviation;
          } else {
            totalDeviation += deviation;
          }
        }
      }

      if (validComparisons > 0) {
        double avgDeviation = totalDeviation / validComparisons;
        trajectoryScore = math.max(0.0, 100.0 - (avgDeviation * 300.0));
      }
    }

    // 2. Overall pitch comparison (Macro)
    // Compare the average pitch to see if they are in the same register
    final pitchRatio = user.pitch / reference.pitch;
    final pitchDeviation = (pitchRatio - 1.0).abs();
    // Allow for octave differences (0.5, 2.0, 4.0 etc)
    double macroScore = 100.0;
    if (pitchDeviation > 0.1) {
      // Check for octave equivalence
      double octaveDiff = (math.log(pitchRatio) / math.log(2)).abs();
      double nearestOctave = octaveDiff.roundToDouble();
      double octaveDeviation = (octaveDiff - nearestOctave).abs();

      // Score based on how close to a perfect octave
      macroScore = math.max(0, 100.0 - (octaveDeviation * 200.0));
    } else {
      macroScore = math.max(0, 100.0 - (pitchDeviation * 500.0));
    }

    // 3. Note matching comparison (Micro)
    if (reference.notes.isEmpty || user.notes.isEmpty) {
      if (trajectoryScore > 0) return trajectoryScore;
      return macroScore;
    }

    final refNotes = reference.notes.map(_normalizeSargamNote).toSet();
    final userNotes = user.notes.map(_normalizeSargamNote).toSet();

    if (refNotes.isEmpty) {
      if (trajectoryScore > 0) return trajectoryScore;
      return macroScore;
    }

    // Calculate intersection overlap
    int matchedNotes = 0;
    for (final refNote in refNotes) {
      if (userNotes.contains(refNote)) matchedNotes++;
    }
    double noteMatchScore = (matchedNotes / refNotes.length) * 100.0;

    // Penalize extra notes slightly
    int extraNotes = 0;
    for (final userNote in userNotes) {
      if (!refNotes.contains(userNote)) extraNotes++;
    }
    if (extraNotes > 0) {
      noteMatchScore -= (extraNotes / userNotes.length) * 10.0;
    }

    if (trajectoryScore > 0) {
      // Weighted average: 50% trajectory, 30% notes, 20% macro
      return (trajectoryScore * 0.5 + noteMatchScore * 0.3 + macroScore * 0.2)
          .clamp(0.0, 100.0);
    }

    // Weighted average: 70% note matching, 30% overall pitch stability
    return (noteMatchScore * 0.7 + macroScore * 0.3).clamp(0.0, 100.0);
  }

  /// Enhanced tempo accuracy calculation
  double _calculateEnhancedTempoAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    // If user tempo was not detected, they likely weren't singing – return 0 instead of a high neutral.
    if (user.tempo == 0) return 0.0;
    if (reference.tempo == 0) {
      return 50.0; // Neutral only when reference is missing
    }

    final tempoRatio = user.tempo / reference.tempo;
    final tempoDeviation = (tempoRatio - 1.0).abs();

    // Continuous exponential drop-off for smoother scoring
    // deviation 0.0 -> score 100
    // deviation 0.1 (10%) -> score ~90
    // deviation 0.2 (20%) -> score ~80
    // deviation 0.5 (50%) -> score ~50
    final accuracy = 100.0 * math.exp(-2.0 * tempoDeviation);
    return accuracy.clamp(0.0, 100.0);
  }

  /// Enhanced rhythm accuracy using cross-correlation
  double _calculateEnhancedRhythmAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    // If user has no rhythm data, they weren't singing – return 0, not a high neutral.
    if (user.rhythm.isEmpty) return 0.0;
    if (reference.rhythm.isEmpty) {
      return 50.0; // Neutral only when reference is missing
    }

    final correlation = _crossCorrelation(reference.rhythm, user.rhythm);

    // Normalize correlation to 0-100 range
    // correlation of 1.0 -> 100, 0.0 -> 50, -1.0 -> 0
    final accuracy = math.min(100.0, (correlation + 1.0) * 50.0);

    return accuracy.clamp(0.0, 100.0); // Removed artificial 50% floor
  }

  /// Calculate timbre accuracy using spectral features
  double _calculateTimbreAccuracy(
    AudioCharacteristics reference,
    AudioCharacteristics user,
  ) {
    // If user has no spectrum, likely silent – return 0 instead of a high neutral.
    if (user.spectrum.isEmpty) return 0.0;
    if (reference.spectrum.isEmpty) return 50.0;

    // Calculate spectral centroid similarity
    final refCentroid = reference.spectralCentroid;
    final userCentroid = user.spectralCentroid;

    if (userCentroid == 0) return 0.0;
    if (refCentroid == 0) return 50.0;

    final centroidRatio = userCentroid / refCentroid;
    final centroidDeviation = (centroidRatio - 1.0).abs();

    // Timbre continuous scoring
    // deviation 0.0 -> 100
    // deviation 0.3 -> ~85
    // deviation 1.0 -> ~60 (clamped)
    final accuracy = 100.0 * math.exp(-1.5 * centroidDeviation);
    return accuracy.clamp(0.0, 100.0);
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
    final missedNotes = <String>{}; // Use Set to avoid duplicates

    // Normalize user's detected notes for comparison
    final userNotesNormalized = user.notes.map(_normalizeSargamNote).toSet();

    print('User detected notes (raw): ${user.notes}');
    print('User detected notes (normalized): $userNotesNormalized');
    print('Expected notes: $expectedNotes');
    print('Reference notes from audio: ${reference.notes}');

    // 1. Check against explicitly expected notes (from RagaData)
    for (final expectedNote in expectedNotes) {
      final normalizedExpected = _normalizeSargamNote(expectedNote);
      if (!userNotesNormalized.contains(normalizedExpected)) {
        missedNotes.add(expectedNote);
      }
    }

    // 2. Also check against what was actually found in the reference audio
    // This handles cases where RagaData might be minimal but the audio has more nuances
    // Only add if it's a "main" note (appears frequently/strongly)
    // For now, we trust the reference analysis
    final refNotesNormalized = reference.notes
        .map(_normalizeSargamNote)
        .toSet();
    for (final refNote in reference.notes) {
      // Use original to preserve formatting if added
      final normalized = _normalizeSargamNote(refNote);
      if (refNotesNormalized.contains(normalized) &&
          !userNotesNormalized.contains(normalized)) {
        // Only add if not already covered by expectedNotes logic to avoid duplicates with different formatting
        // But we used Set<String> for missedNotes, so safe to add.
        // We prefer the formatting from expectedNotes if available.
        bool alreadyAccounted = false;
        for (final mn in missedNotes) {
          if (_normalizeSargamNote(mn) == normalized) {
            alreadyAccounted = true;
            break;
          }
        }

        if (!alreadyAccounted) {
          missedNotes.add(refNote);
        }
      }
    }

    print('Missed notes: $missedNotes');
    return missedNotes.toList();
  }

  /// Normalize Sargam note for comparison (remove flats/sharps)
  String _normalizeSargamNote(String note) {
    // Remove flat and sharp symbols for basic comparison
    return note
        .replaceAll('♭', '')
        .replaceAll('♯', '')
        .replaceAll('#', '')
        .trim();
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

    // Pitch-related suggestions
    if (pitchAccuracy < 60) {
      suggestions.add(
        'Practice swara (note) accuracy slowly. Use a tanpura or shruti box for reference.',
      );
      suggestions.add(
        'Focus on sa-pa (tonic-fifth) interval to stabilize pitch.',
      );
    } else if (pitchAccuracy < 75) {
      suggestions.add(
        'Good pitch awareness! Practice meend (glides) between notes for better control.',
      );
    } else if (pitchAccuracy >= 90) {
      suggestions.add(
        'Excellent pitch accuracy! Your swara control is impressive.',
      );
    }

    // Rhythm-related suggestions
    if (rhythmAccuracy < 60) {
      suggestions.add(
        'Practice with a tabla or metronome to improve taal (rhythm) consistency.',
      );
      suggestions.add('Start with simple taals like Dadra or Kaharwa.');
    } else if (rhythmAccuracy < 75) {
      suggestions.add(
        'Good rhythm sense! Try practicing with tabla accompaniment.',
      );
    } else if (rhythmAccuracy >= 90) {
      suggestions.add(
        'Excellent laya (tempo) control! Your rhythm is very steady.',
      );
    }

    // Tempo-related suggestions
    if (tempoAccuracy < 60) {
      suggestions.add(
        'Practice at slower laya (tempo) first, then gradually increase speed.',
      );
    } else if (tempoAccuracy >= 85) {
      suggestions.add(
        'Great tempo consistency! You maintained good laya throughout.',
      );
    }

    // Note-specific suggestions
    if (missedNotes.isNotEmpty && missedNotes.length <= 3) {
      suggestions.add(
        'Focus on these swaras: ${missedNotes.join(', ')}. Practice them individually first.',
      );
    } else if (missedNotes.length > 3) {
      suggestions.add(
        'Practice the complete aaroh-avroh slowly to strengthen all swaras.',
      );
    }

    // Timbre suggestions (only if poor)
    if (timbreAccuracy < 65) {
      suggestions.add(
        'Work on breath support and voice placement for better tone quality.',
      );
    }

    // Overall encouragement
    final overallScore = (pitchAccuracy + tempoAccuracy + rhythmAccuracy) / 3;
    if (overallScore >= 85) {
      suggestions.add(
        'Outstanding performance! Try exploring alankars (embellishments) in this raga.',
      );
    } else if (overallScore >= 70) {
      suggestions.add(
        'Good progress! Regular daily practice will help improve consistency.',
      );
    } else if (overallScore >= 50) {
      suggestions.add(
        'Keep practicing! Focus on one aspect at a time - pitch, then rhythm, then tempo.',
      );
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        'Good effort! Continue practicing to improve your skills.',
      );
    }

    return suggestions.take(4).toList(); // Limit to 4 suggestions
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

    // Overall performance assessment
    if (overall >= 90) {
      buffer.write(
        '🌟 Outstanding! Your performance shows excellent mastery. ',
      );
    } else if (overall >= 80) {
      buffer.write('🎵 Very good! You\'re showing strong skills. ');
    } else if (overall >= 70) {
      buffer.write('👍 Good effort! You\'re on the right track. ');
    } else if (overall >= 60) {
      buffer.write('📈 Making progress! Keep up the practice. ');
    } else {
      buffer.write('🎯 Keep practicing! Every session helps you improve. ');
    }

    // Highlight strengths
    final strengths = <String>[];
    if (pitch >= 85) strengths.add('pitch control');
    if (tempo >= 85) strengths.add('tempo consistency');
    if (rhythm >= 85) strengths.add('rhythm accuracy');

    if (strengths.isNotEmpty) {
      buffer.write(
        'Your ${strengths.join(' and ')} ${strengths.length > 1 ? 'are' : 'is'} excellent. ',
      );
    }

    // Areas for improvement (be constructive)
    final improvements = <String>[];
    if (pitch < 70) improvements.add('swara accuracy');
    if (tempo < 70) improvements.add('laya consistency');
    if (rhythm < 70) improvements.add('taal precision');

    if (improvements.isNotEmpty) {
      buffer.write('Focus on improving ${improvements.join(' and ')}. ');
    }

    // Missed notes feedback
    if (missedNotes.isNotEmpty) {
      if (missedNotes.length <= 2) {
        buffer.write('Practice these swaras: ${missedNotes.join(', ')}. ');
      } else {
        buffer.write(
          'Review the complete note sequence, especially: ${missedNotes.take(3).join(', ')}. ',
        );
      }
    }

    // Encouraging close
    if (overall >= 80) {
      buffer.write('You\'re ready for more advanced exercises!');
    } else if (overall >= 60) {
      buffer.write('Regular practice will help you reach the next level.');
    } else {
      buffer.write('Take your time and practice each element separately.');
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
    try {
      if (_currentRecordingPath == null) return [];

      final file = File(_currentRecordingPath!);
      if (!await file.exists()) return [];

      final length = await file.length();
      // Need at least header (44 bytes) + some data
      if (length < 44 + _windowSize * 2) return [];

      // Open file for random access to read only the tail
      final raf = await file.open(mode: FileMode.read);
      try {
        final bytesToRead = _windowSize * 2;
        final startPos = math.max(44, length - bytesToRead);
        
        // Ensure we start on an even byte index for 16-bit PCM
        final adjustedStartPos = (startPos - 44) % 2 != 0 ? startPos - 1 : startPos;
        
        await raf.setPosition(math.max(44, adjustedStartPos));
        final recentBytes = await raf.read(bytesToRead);
        
        final samples = <double>[];
        for (int i = 0; i < recentBytes.length - 1; i += 2) {
          int sample = recentBytes[i] | (recentBytes[i + 1] << 8);
          if (sample >= 32768) sample -= 65536;
          samples.add(sample / 32768.0);
        }
        return samples;
      } finally {
        await raf.close();
      }
    } catch (e) {
      print('Error reading recent audio data: $e');
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

  /// Convert frequency to Sargam note (Indian classical music notation)
  /// Uses C = Sa as the base (common in Indian classical music)
  String _frequencyToNote(double frequency) {
    if (frequency <= 0) return '';

    const a4 = 440.0;
    final n = 12 * math.log(frequency / a4) / math.log(2);
    final noteNumber = (n + 9).round() % 12;

    // Return Sargam notes directly instead of Western notes
    // This matches the expected format in RagaData.notes
    // Mapping: C=Sa, C#=Re♭, D=Re, D#=Ga♭, E=Ga, F=Ma, F#=Ma#, G=Pa, G#=Dha♭, A=Dha, A#=Ni♭, B=Ni
    const sargamNotes = [
      'Sa', // C
      'Re', // C# (using Re instead of Re♭ for simpler matching)
      'Re', // D
      'Ga', // D# (using Ga instead of Ga♭ for simpler matching)
      'Ga', // E
      'Ma', // F
      'Ma', // F# (using Ma instead of Ma# for simpler matching)
      'Pa', // G
      'Dha', // G# (using Dha instead of Dha♭ for simpler matching)
      'Dha', // A
      'Ni', // A# (using Ni instead of Ni♭ for simpler matching)
      'Ni', // B
    ];

    if (noteNumber >= 0 && noteNumber < sargamNotes.length) {
      return sargamNotes[noteNumber];
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
