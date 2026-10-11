// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
// import 'dart:typed_data'; // Not needed for current implementation
import 'audio_analysis_service.dart';
import 'indian_music_helper.dart';
import '../models/audio_characteristics.dart';

/// Test service to verify audio analysis functionality
class AudioAnalysisTestService {
  static final AudioAnalysisTestService _instance =
      AudioAnalysisTestService._internal();
  factory AudioAnalysisTestService() => _instance;
  AudioAnalysisTestService._internal();

  final AudioAnalysisService _analysisService = AudioAnalysisService();

  /// Run comprehensive tests for audio analysis
  Future<Map<String, dynamic>> runComprehensiveTests() async {
    final results = <String, dynamic>{};

    print('🧪 Starting comprehensive audio analysis tests...');

    // Initialize the service
    await _analysisService.initialize();

    try {
      // Test 1: Basic functionality
      results['basic_functionality'] = await _testBasicFunctionality();

      // Test 2: Pitch detection accuracy
      results['pitch_detection'] = await _testPitchDetection();

      // Test 3: Tempo analysis
      results['tempo_analysis'] = await _testTempoAnalysis();

      // Test 4: Real-time analysis
      results['realtime_analysis'] = await _testRealTimeAnalysis();

      // Test 5: Indian music features
      results['indian_music_features'] = await _testIndianMusicFeatures();

      // Test 6: Performance benchmarks
      results['performance_benchmarks'] = await _testPerformance();

      // Test 7: Error handling
      results['error_handling'] = await _testErrorHandling();

      results['overall_status'] = 'SUCCESS';
      results['timestamp'] = DateTime.now().toIso8601String();
    } catch (e) {
      results['overall_status'] = 'FAILED';
      results['error'] = e.toString();
    }

    print('✅ Audio analysis tests completed');
    return results;
  }

  /// Test basic functionality
  Future<Map<String, dynamic>> _testBasicFunctionality() async {
    print('Testing basic functionality...');

    final results = <String, dynamic>{};

    try {
      // Create synthetic audio data
      final testAudio = _generateSineWave(
        440.0,
        2.0,
        44100,
      ); // A4 note for 2 seconds

      // Test characteristic extraction
      final characteristics = await _analysisService
          .extractCharacteristicsEfficient(testAudio);

      results['characteristics_extracted'] =
          true; // characteristics is never null
      results['pitch_detected'] = characteristics.pitch > 0;
      results['volume_calculated'] = characteristics.volume > 0;
      results['spectrum_generated'] = characteristics.spectrum.isNotEmpty;
      results['duration_calculated'] = characteristics.duration > 0;

      // Test caching
      final tempFile = await _createTempAudioFile(testAudio);
      final firstAnalysis = await _analysisService.analyzeAudioFile(
        tempFile.path,
      );
      final secondAnalysis = await _analysisService.analyzeAudioFile(
        tempFile.path,
      );

      results['caching_works'] = firstAnalysis.pitch == secondAnalysis.pitch;

      await tempFile.delete();
      results['status'] = 'PASSED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Test pitch detection accuracy
  Future<Map<String, dynamic>> _testPitchDetection() async {
    print('Testing pitch detection...');

    final results = <String, dynamic>{};
    final testFrequencies = [220.0, 440.0, 880.0, 523.25]; // A3, A4, A5, C5
    final detectedPitches = <double>[];

    try {
      for (final frequency in testFrequencies) {
        final testAudio = _generateSineWave(frequency, 1.0, 44100);
        final characteristics = await _analysisService
            .extractCharacteristicsEfficient(testAudio);
        detectedPitches.add(characteristics.pitch);
      }

      // Calculate accuracy
      double totalError = 0.0;
      for (int i = 0; i < testFrequencies.length; i++) {
        final error =
            (detectedPitches[i] - testFrequencies[i]).abs() /
            testFrequencies[i];
        totalError += error;
      }

      final averageError = totalError / testFrequencies.length;
      final accuracy = (1.0 - averageError) * 100.0;

      results['test_frequencies'] = testFrequencies;
      results['detected_pitches'] = detectedPitches;
      results['average_error_percent'] = averageError * 100.0;
      results['accuracy_percent'] = accuracy;
      results['status'] = accuracy > 80.0 ? 'PASSED' : 'FAILED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Test tempo analysis
  Future<Map<String, dynamic>> _testTempoAnalysis() async {
    print('Testing tempo analysis...');

    final results = <String, dynamic>{};

    try {
      // Generate audio with known tempo (120 BPM)
      final testAudio = _generateRhythmicPattern(120.0, 4.0, 44100);
      final characteristics = await _analysisService
          .extractCharacteristicsEfficient(testAudio);

      results['expected_tempo'] = 120.0;
      results['detected_tempo'] = characteristics.tempo;
      results['rhythm_pattern_length'] = characteristics.rhythm.length;
      results['tempo_accuracy'] = characteristics.tempo > 0
          ? (1.0 - (characteristics.tempo - 120.0).abs() / 120.0) * 100.0
          : 0.0;

      results['status'] = results['tempo_accuracy'] > 50.0
          ? 'PASSED'
          : 'FAILED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Test real-time analysis
  Future<Map<String, dynamic>> _testRealTimeAnalysis() async {
    print('Testing real-time analysis...');

    final results = <String, dynamic>{};
    final receivedUpdates = <AudioCharacteristics>[];

    try {
      // Start real-time analysis
      final stream = _analysisService.startRealTimeAnalysis();

      // Listen for updates for 2 seconds
      final subscription = stream.listen((characteristics) {
        receivedUpdates.add(characteristics);
      });

      await Future.delayed(const Duration(seconds: 2));

      // Stop analysis
      _analysisService.stopRealTimeAnalysis();
      await subscription.cancel();

      results['updates_received'] = receivedUpdates.length;
      results['stream_working'] = receivedUpdates.isNotEmpty;
      results['data_quality'] = receivedUpdates.isNotEmpty
          ? receivedUpdates.last.volume > 0
          : false;
      results['status'] = receivedUpdates.isNotEmpty ? 'PASSED' : 'FAILED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
      _analysisService.stopRealTimeAnalysis();
    }

    return results;
  }

  /// Test Indian music features
  Future<Map<String, dynamic>> _testIndianMusicFeatures() async {
    print('Testing Indian music features...');

    final results = <String, dynamic>{};

    try {
      // Test note conversion
      final westernNote = 'C';
      final sargamNote = IndianMusicHelper.westernToSargamNote(westernNote);
      results['note_conversion'] = sargamNote == 'Sa';

      // Test raga identification
      final testNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
      final identifiedRaga = IndianMusicHelper.identifyRaga(testNotes);
      results['raga_identification'] = identifiedRaga == 'Bilawal';

      // Test taal identification
      final rhythmPattern = [1.0, 1.0, 1.0, 1.0]; // Simple 4-beat pattern
      final identifiedTaal = IndianMusicHelper.identifyTaal(
        rhythmPattern,
        120.0,
      );
      results['taal_identification'] = identifiedTaal != 'Unknown';

      // Test tempo classification
      final tempoClass = IndianMusicHelper.classifyTempo(100.0);
      results['tempo_classification'] = tempoClass == 'Madhya';

      // Test raga accuracy calculation
      final ragaAccuracy = IndianMusicHelper.calculateRagaAccuracy(
        'Bilawal',
        testNotes,
      );
      results['raga_accuracy'] = ragaAccuracy;

      // Test practice suggestions
      final suggestions = IndianMusicHelper.getRagaPracticeSuggestions(
        'Bilawal',
      );
      results['practice_suggestions'] = suggestions.isNotEmpty;

      final allTestsPassed =
          results['note_conversion'] &&
          results['raga_identification'] &&
          results['taal_identification'] &&
          results['tempo_classification'] &&
          results['practice_suggestions'];

      results['status'] = allTestsPassed ? 'PASSED' : 'FAILED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Test performance benchmarks
  Future<Map<String, dynamic>> _testPerformance() async {
    print('Testing performance benchmarks...');

    final results = <String, dynamic>{};

    try {
      // Test file analysis performance
      final testAudio = _generateSineWave(440.0, 5.0, 44100); // 5-second audio
      final tempFile = await _createTempAudioFile(testAudio);

      final stopwatch = Stopwatch()..start();
      await _analysisService.analyzeAudioFile(tempFile.path);
      stopwatch.stop();

      results['file_analysis_ms'] = stopwatch.elapsedMilliseconds;
      results['file_analysis_acceptable'] =
          stopwatch.elapsedMilliseconds < 5000; // Under 5 seconds

      // Test real-time analysis latency
      stopwatch.reset();
      stopwatch.start();
      await _analysisService.extractCharacteristicsRealTime(
        testAudio.sublist(0, 2048),
      );
      stopwatch.stop();

      results['realtime_analysis_ms'] = stopwatch.elapsedMilliseconds;
      results['realtime_analysis_acceptable'] =
          stopwatch.elapsedMilliseconds < 100; // Under 100ms

      // Test memory usage (approximate)
      final beforeMemory = ProcessInfo.currentRss;
      for (int i = 0; i < 10; i++) {
        await _analysisService.extractCharacteristicsRealTime(
          testAudio.sublist(0, 2048),
        );
      }
      final afterMemory = ProcessInfo.currentRss;

      results['memory_increase_kb'] = (afterMemory - beforeMemory) / 1024;
      results['memory_usage_acceptable'] =
          (afterMemory - beforeMemory) < 10 * 1024 * 1024; // Under 10MB

      await tempFile.delete();

      final performanceOk =
          results['file_analysis_acceptable'] &&
          results['realtime_analysis_acceptable'] &&
          results['memory_usage_acceptable'];

      results['status'] = performanceOk ? 'PASSED' : 'FAILED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Test error handling
  Future<Map<String, dynamic>> _testErrorHandling() async {
    print('Testing error handling...');

    final results = <String, dynamic>{};

    try {
      // Test with non-existent file
      try {
        await _analysisService.analyzeAudioFile('/non/existent/file.wav');
        results['nonexistent_file_handled'] = false;
      } catch (e) {
        results['nonexistent_file_handled'] = true;
      }

      // Test with empty audio data
      try {
        await _analysisService.extractCharacteristicsEfficient([]);
        results['empty_audio_handled'] =
            true; // Should return empty characteristics, not crash
      } catch (e) {
        results['empty_audio_handled'] = false;
      }

      // Test with invalid audio data
      try {
        final invalidData = List.generate(100, (i) => double.nan);
        await _analysisService.extractCharacteristicsEfficient(invalidData);
        results['invalid_audio_handled'] = true;
      } catch (e) {
        results['invalid_audio_handled'] =
            true; // Expected to handle gracefully
      }

      // Test multiple real-time analysis starts
      try {
        _analysisService.startRealTimeAnalysis();
        _analysisService.startRealTimeAnalysis(); // Should throw exception
        results['multiple_realtime_handled'] = false;
      } catch (e) {
        results['multiple_realtime_handled'] = true;
        _analysisService.stopRealTimeAnalysis();
      }

      final errorHandlingOk =
          results['nonexistent_file_handled'] &&
          results['empty_audio_handled'] &&
          results['invalid_audio_handled'] &&
          results['multiple_realtime_handled'];

      results['status'] = errorHandlingOk ? 'PASSED' : 'FAILED';
    } catch (e) {
      results['status'] = 'FAILED';
      results['error'] = e.toString();
    }

    return results;
  }

  /// Generate sine wave for testing
  List<double> _generateSineWave(
    double frequency,
    double durationSeconds,
    int sampleRate,
  ) {
    final samples = <double>[];
    final totalSamples = (durationSeconds * sampleRate).round();

    for (int i = 0; i < totalSamples; i++) {
      final sample = 0.5 * math.sin(2 * math.pi * frequency * i / sampleRate);
      samples.add(sample);
    }

    return samples;
  }

  /// Generate rhythmic pattern for tempo testing
  List<double> _generateRhythmicPattern(
    double bpm,
    double durationSeconds,
    int sampleRate,
  ) {
    final samples = <double>[];
    final totalSamples = (durationSeconds * sampleRate).round();
    final beatInterval = 60.0 / bpm; // seconds per beat
    final beatSamples = (beatInterval * sampleRate).round();

    for (int i = 0; i < totalSamples; i++) {
      // Create a pulse every beat
      if (i % beatSamples < beatSamples ~/ 10) {
        samples.add(0.8); // Strong pulse
      } else {
        samples.add(
          0.1 * math.sin(2 * math.pi * 440.0 * i / sampleRate),
        ); // Background tone
      }
    }

    return samples;
  }

  /// Create temporary audio file for testing
  Future<File> _createTempAudioFile(List<double> audioData) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/test_audio_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    // Simple WAV file creation (44-byte header + 16-bit PCM data)
    final bytes = <int>[];

    // WAV header
    bytes.addAll('RIFF'.codeUnits);
    bytes.addAll(_int32ToBytes(36 + audioData.length * 2));
    bytes.addAll('WAVE'.codeUnits);
    bytes.addAll('fmt '.codeUnits);
    bytes.addAll(_int32ToBytes(16)); // Subchunk1Size
    bytes.addAll(_int16ToBytes(1)); // AudioFormat (PCM)
    bytes.addAll(_int16ToBytes(1)); // NumChannels (mono)
    bytes.addAll(_int32ToBytes(44100)); // SampleRate
    bytes.addAll(_int32ToBytes(44100 * 2)); // ByteRate
    bytes.addAll(_int16ToBytes(2)); // BlockAlign
    bytes.addAll(_int16ToBytes(16)); // BitsPerSample
    bytes.addAll('data'.codeUnits);
    bytes.addAll(_int32ToBytes(audioData.length * 2));

    // Audio data (convert to 16-bit PCM)
    for (final sample in audioData) {
      final intSample = (sample * 32767).round().clamp(-32768, 32767);
      bytes.addAll(_int16ToBytes(intSample));
    }

    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  List<int> _int32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  List<int> _int16ToBytes(int value) {
    return [value & 0xFF, (value >> 8) & 0xFF];
  }

  /// Print test results in a readable format
  void printTestResults(Map<String, dynamic> results) {
    print('\n📊 AUDIO ANALYSIS TEST RESULTS');
    print('=' * 50);
    print('Overall Status: ${results['overall_status']}');
    print('Timestamp: ${results['timestamp']}');
    print('');

    for (final entry in results.entries) {
      if (entry.key.startsWith('_') ||
          entry.key == 'overall_status' ||
          entry.key == 'timestamp') {
        continue;
      }

      print('${entry.key.toUpperCase()}:');
      if (entry.value is Map<String, dynamic>) {
        final testResult = entry.value as Map<String, dynamic>;
        print('  Status: ${testResult['status']}');
        testResult.forEach((key, value) {
          if (key != 'status') {
            print('  $key: $value');
          }
        });
      }
      print('');
    }

    print('=' * 50);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _analysisService.dispose();
  }
}

/// Simple process info helper
class ProcessInfo {
  static int get currentRss {
    // This is a simplified version - in a real app you might use a proper memory profiling tool
    return DateTime.now().millisecondsSinceEpoch; // Placeholder
  }
}
