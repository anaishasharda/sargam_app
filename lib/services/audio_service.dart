import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tts_audio_service.dart';
import 'audio_analysis_service.dart';
import '../models/audio_characteristics.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TTSAudioService _ttsService = TTSAudioService();
  final AudioAnalysisService _analysisService = AudioAnalysisService();

  bool _isPlaying = false;
  bool _isRecording = false;
  String? _currentRecordingPath;

  bool get isPlaying => _isPlaying;
  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();

    // Initialize TTS service
    await _ttsService.initialize();

    // Initialize enhanced audio analysis service
    await _analysisService.initialize();

    return microphoneStatus.isGranted && storageStatus.isGranted;
  }

  /// Check if an audio file exists in assets
  Future<bool> checkAudioFileExists(String audioPath) async {
    try {
      // Remove 'assets/' prefix if present
      String assetPath = audioPath;
      if (assetPath.startsWith('assets/')) {
        assetPath = assetPath.substring(7);
      }

      print('Checking if audio file exists: $assetPath');

      // Create a new AudioPlayer instance to avoid conflicts
      final testPlayer = AudioPlayer();
      try {
        await testPlayer.setSource(AssetSource(assetPath));
        await testPlayer.dispose();
        print('Audio file exists: $assetPath');
        return true;
      } catch (e) {
        await testPlayer.dispose();
        print('Audio file does not exist: $audioPath');
        print('Error: $e');
        return false;
      }
    } catch (e) {
      print('Audio file does not exist: $audioPath');
      print('Error: $e');
      return false;
    }
  }

  Future<void> playAudio(
    String audioPath, {
    String? ragaName,
    String? practiceType,
  }) async {
    try {
      if (_isPlaying) {
        await stopAudio();
      }

      // Try to play actual audio file
      try {
        // Remove 'assets/' prefix if present, as AssetSource expects path relative to assets folder
        String assetPath = audioPath;
        if (assetPath.startsWith('assets/')) {
          assetPath = assetPath.substring(7); // Remove 'assets/' prefix
        }

        print('Attempting to play audio file: $assetPath');
        print('Original path: $audioPath');

        // Set up completion handler
        _audioPlayer.onPlayerComplete.listen((event) {
          print('Audio playback completed');
          _isPlaying = false;
        });

        await _audioPlayer.play(AssetSource(assetPath));
        _isPlaying = true;
        print('Successfully playing audio file: $assetPath');
        return;
      } catch (e) {
        print('Failed to play audio file: $audioPath');
        print('Error details: $e');
        // Don't throw, fall through to TTS
      }

      // Fallback to TTS if audio file doesn't exist
      if (ragaName != null && practiceType != null) {
        _isPlaying = true;

        switch (practiceType.toLowerCase()) {
          case 'aaroh':
            await _ttsService.playAaroh(ragaName);
            break;
          case 'avroh':
            await _ttsService.playAvroh(ragaName);
            break;
          case 'swarmalika':
            await _ttsService.playSwarmalika(ragaName);
            break;
          default:
            await _ttsService.playAaroh(ragaName);
        }
      } else {
        // Simulate playing if no raga info
        _isPlaying = true;
        Future.delayed(const Duration(seconds: 3), () {
          _isPlaying = false;
        });
      }
    } catch (e) {
      print('Error playing audio: $e');
      _isPlaying = false;
    }
  }

  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      await _ttsService.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        // Let the recorder decide the path - works more reliably across platforms
        // The recorder will return the actual path when stopped
        final directory = Directory.systemTemp;
        _currentRecordingPath =
            '${directory.path}/practice_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav, // Use WAV for proper analysis
            bitRate: 128000,
            sampleRate: 44100,
            numChannels: 1, // Mono for consistency with analysis
          ),
          path: _currentRecordingPath!,
        );

        _isRecording = true;
        print('Recording started: $_currentRecordingPath');
      } else {
        throw Exception('Microphone permission not granted');
      }
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      // Get the actual path from the recorder
      final path = await _audioRecorder.stop();
      _isRecording = false;

      if (path == null) {
        print('Recording stopped but no path returned');
        return null;
      }

      print('Recording stopped, path: $path');

      // Wait a moment for file to be fully written
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify the file exists
      final file = File(path);
      if (await file.exists()) {
        final fileSize = await file.length();
        print('Recording file verified: $path (size: $fileSize bytes)');
        _currentRecordingPath = path;
        return path;
      } else {
        print('Warning: Recording file not found at $path');
        // Try the path we specified during start
        if (_currentRecordingPath != null) {
          final altFile = File(_currentRecordingPath!);
          if (await altFile.exists()) {
            print('Found recording at alternate path: $_currentRecordingPath');
            return _currentRecordingPath;
          }
        }
        return null;
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Start real-time analysis with recording
  Future<Stream<AudioCharacteristics>> startRealTimeAnalysis() async {
    if (_isRecording) {
      throw Exception('Already recording');
    }

    _isRecording = true;
    return await _analysisService.startRealTimeAnalysisWithRecording();
  }

  /// Stop real-time analysis and recording
  Future<void> stopRealTimeAnalysis() async {
    await _analysisService.stopRealTimeAnalysisWithRecording();
    _isRecording = false;
  }

  /// Get the analysis service instance for direct access
  AudioAnalysisService get analysisService => _analysisService;

  Future<void> dispose() async {
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    await _audioRecorder.dispose();
    await _ttsService.dispose();
    await _analysisService.dispose();
  }
}
