import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tts_audio_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TTSAudioService _ttsService = TTSAudioService();

  bool _isPlaying = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _currentRagaName;
  String? _currentPracticeType;

  bool get isPlaying => _isPlaying;
  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;

  Future<bool> requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();
    
    // Initialize TTS service
    await _ttsService.initialize();

    return microphoneStatus.isGranted && storageStatus.isGranted;
  }

  Future<void> playAudio(String audioPath, {String? ragaName, String? practiceType}) async {
    try {
      if (_isPlaying) {
        await stopAudio();
      }

      _currentRagaName = ragaName;
      _currentPracticeType = practiceType;

      // Try to play actual audio file first
      try {
        await _audioPlayer.play(AssetSource(audioPath));
        _isPlaying = true;
        print('Playing audio file: $audioPath');
        return;
      } catch (e) {
        print('Audio file not found, using TTS: $audioPath');
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
        final directory = Directory.systemTemp;
        _currentRecordingPath =
            '${directory.path}/practice_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );

        _isRecording = true;
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
      final path = await _audioRecorder.stop();
      _isRecording = false;
      return path;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _audioRecorder.dispose();
    await _ttsService.dispose();
  }
}
