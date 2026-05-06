import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'tts_audio_service.dart';
import 'audio_analysis_service.dart';
import 'realtime_audio_service.dart';
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
  StreamSubscription<PlayerState>? _playerStateSub;

  // Streaming-recorder state. We capture PCM via record.startStream and
  // simultaneously feed each chunk into the realtime analyzer so the
  // sing-along graph can show live pitch from the same mic source.
  StreamSubscription<Uint8List>? _recordStreamSub;
  IOSink? _pcmSink;
  int _pcmBytesWritten = 0;
  static const int _recSampleRate = 44100;

  bool get isPlaying => _isPlaying;
  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  AudioPlayer get player => _audioPlayer;

  Future<bool> requestPermissions() async {
    final microphoneStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();

    await _ttsService.initialize();
    await _analysisService.initialize();

    return microphoneStatus.isGranted && storageStatus.isGranted;
  }

  /// Check if an audio file exists in assets by attempting to load it.
  Future<bool> checkAudioFileExists(String audioPath) async {
    try {
      String assetPath = audioPath;
      if (assetPath.startsWith('assets/')) {
        assetPath = assetPath.substring(7);
      }
      print('Checking if audio file exists: $assetPath');

      final testPlayer = AudioPlayer();
      try {
        await testPlayer.setAsset('assets/$assetPath');
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

  /// Map a transpose value (0..n semitones) to just_audio pitch ratio.
  /// Pitch ratio = 2^(semitones/12). just_audio supports
  /// `setPitch` natively on iOS/Android.
  Future<void> setTranspose(int semitones) async {
    try {
      final ratio = math.pow(2.0, semitones / 12.0).toDouble();
      await _audioPlayer.setPitch(ratio);
    } catch (e) {
      print('Error setting transpose: $e');
    }
  }

  Future<void> playAudio(
    String audioPath, {
    String? ragaName,
    String? practiceType,
    int transposeSemitones = 0,
    double speed = 1.0,
  }) async {
    try {
      await stopAudio();

      try {
        String assetPath = audioPath;
        if (assetPath.startsWith('assets/')) {
          assetPath = assetPath.substring(7);
        }

        print('Attempting to play audio file: $assetPath');

        await _audioPlayer.setAsset('assets/$assetPath');
        await _audioPlayer.setVolume(1.0);
        await setTranspose(transposeSemitones);
        try {
          // Tempo control is independent of pitch on iOS/Android via just_audio.
          await _audioPlayer.setSpeed(speed);
        } catch (e) {
          print('Error setting speed: $e');
        }

        _playerStateSub?.cancel();
        _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            print('Audio playback completed');
            _isPlaying = false;
          }
        });

        // Don't await play() — it completes only when playback finishes.
        // ignore: discarded_futures
        _audioPlayer.play();
        _isPlaying = true;
        print('Successfully playing audio file: $assetPath');
        return;
      } catch (e) {
        print('Failed to play audio file: $audioPath');
        print('Error details: $e');
      }

      if (ragaName != null && practiceType != null) {
        print('Falling back to TTS for $ragaName - $practiceType');
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

  /// Get a temporary file for an asset audio. Needed because
  /// AudioAnalysisService requires a File object.
  Future<File?> getAssetFile(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer;

      final directory = Directory.systemTemp;
      final tempFile = File('${directory.path}/${assetPath.split('/').last}');

      await tempFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      return tempFile;
    } catch (e) {
      print('Error converting asset to file: $e');
      return null;
    }
  }

  /// Start recording. We use [AudioRecorder.startStream] (raw 16-bit PCM)
  /// rather than the file-based [start] so the same mic input can fan out
  /// to (a) a WAV file we write ourselves and (b) the realtime analyzer
  /// driving the sing-along graph. Two competing mic clients used to
  /// silently leave the graph blank.
  Future<void> startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        throw Exception('Microphone permission not granted');
      }

      final directory = Directory.systemTemp;
      _currentRecordingPath =
          '${directory.path}/practice_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Open the file with a placeholder WAV header. We back-fill the
      // size fields on stop() once we know how many PCM bytes we wrote.
      final file = File(_currentRecordingPath!);
      _pcmSink = file.openWrite();
      _pcmSink!.add(_makeWavHeader(dataSize: 0));
      _pcmBytesWritten = 0;

      // Make sure the realtime service is alive and emitting; the graph
      // listens to its dataStream.
      await RealtimeAudioService().initialize();
      await RealtimeAudioService().startExternalAnalysis();

      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _recSampleRate,
          numChannels: 1,
        ),
      );

      _recordStreamSub = stream.listen(
        _onPcmChunk,
        onError: (Object e) {
          print('Recording stream error: $e');
        },
      );

      _isRecording = true;
      print('Recording started (streamed): $_currentRecordingPath');
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      await _cleanupRecordingResources();
    }
  }

  // Counter to throttle diagnostic logs (only log every Nth chunk)
  int _diagCounter = 0;

  void _onPcmChunk(Uint8List chunk) {
    // 1) Persist raw bytes to the file.
    _pcmSink?.add(chunk);
    _pcmBytesWritten += chunk.length;

    // 2) Fan out to realtime analyzer as Float32 samples for the live graph.
    final samples = _pcm16ToFloat32(chunk);

    // ── Diagnostic logging (every 20th chunk = ~2x/sec) ──
    _diagCounter++;
    if (_diagCounter % 20 == 1) {
      // Raw PCM bytes
      final byteData = ByteData.sublistView(chunk);
      final nSamples = chunk.length ~/ 2;

      // Find peak raw int16 value
      int rawMin = 0, rawMax = 0;
      for (int i = 0; i < nSamples; i++) {
        final s = byteData.getInt16(i * 2, Endian.little);
        if (s < rawMin) rawMin = s;
        if (s > rawMax) rawMax = s;
      }

      // Find peak float value
      double fMin = 0, fMax = 0, fRms = 0;
      for (int i = 0; i < samples.length; i++) {
        final v = samples[i];
        if (v < fMin) fMin = v;
        if (v > fMax) fMax = v;
        fRms += v * v;
      }
      fRms = fRms > 0 ? (fRms / samples.length) : 0;
      final rms = fRms > 0 ? (fRms * 1.0) : 0.0; // keep as squared for log

      print('🔬 AUDIO DIAG #$_diagCounter:');
      print('   chunk=${chunk.length} bytes, $nSamples samples');
      print('   raw PCM int16: min=$rawMin, max=$rawMax');
      print('   float32: min=${fMin.toStringAsFixed(6)}, max=${fMax.toStringAsFixed(6)}, rmsSquared=${rms.toStringAsFixed(8)}');
      print('   first 10 raw: ${[for (int i = 0; i < 10 && i < nSamples; i++) byteData.getInt16(i * 2, Endian.little)]}');
      print('   first 10 float: ${[for (int i = 0; i < 10 && i < samples.length; i++) samples[i].toStringAsFixed(5)]}');
    }

    RealtimeAudioService().feedSamples(samples);
  }


  Future<String?> stopRecording() async {
    if (!_isRecording) return _currentRecordingPath;
    try {
      _isRecording = false;
      await _recordStreamSub?.cancel();
      _recordStreamSub = null;

      try {
        await _audioRecorder.stop();
      } catch (e) {
        print('Recorder stop error (non-fatal): $e');
      }

      await RealtimeAudioService().stopExternalAnalysis();

      final dataSize = _pcmBytesWritten;
      await _pcmSink?.flush();
      await _pcmSink?.close();
      _pcmSink = null;

      // Patch the WAV header now that we know the data length.
      if (_currentRecordingPath != null && dataSize > 0) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          final raf = await file.open(mode: FileMode.writeOnlyAppend);
          try {
            // Rewrite the full header in place.
            await raf.setPosition(0);
            await raf.writeFrom(_makeWavHeader(dataSize: dataSize));
          } finally {
            await raf.close();
          }
          print(
            'Recording stopped: $_currentRecordingPath ($dataSize PCM bytes)',
          );
          return _currentRecordingPath;
        }
      }
      print('Recording stopped but no data captured.');
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      await _cleanupRecordingResources();
      return null;
    }
  }

  Future<void> _cleanupRecordingResources() async {
    await _recordStreamSub?.cancel();
    _recordStreamSub = null;
    try {
      await _pcmSink?.flush();
      await _pcmSink?.close();
    } catch (_) {}
    _pcmSink = null;
    try {
      await RealtimeAudioService().stopExternalAnalysis();
    } catch (_) {}
  }

  /// Convert a 16-bit signed little-endian PCM byte chunk into Float32 in
  /// [-1, 1] for the realtime analyzer.
  Float32List _pcm16ToFloat32(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final s = byteData.getInt16(i * 2, Endian.little);
      out[i] = s / 32768.0;
    }
    return out;
  }

  /// Build a canonical 44-byte PCM WAV header for mono 16-bit at the
  /// configured sample rate. Pass [dataSize] = 0 when opening the file
  /// (placeholder) and the real value on close.
  Uint8List _makeWavHeader({required int dataSize}) {
    const channels = 1;
    const bitsPerSample = 16;
    const headerSize = 44;
    final byteRate = _recSampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);

    final out = BytesBuilder();
    void writeStr(String s) => out.add(s.codeUnits);
    void writeU32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    void writeU16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      out.add(b.buffer.asUint8List());
    }

    writeStr('RIFF');
    writeU32(headerSize - 8 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(channels);
    writeU32(_recSampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(bitsPerSample);
    writeStr('data');
    writeU32(dataSize);
    return out.toBytes();
  }

  /// Start real-time analysis with recording.
  Future<Stream<AudioCharacteristics>> startRealTimeAnalysis() async {
    if (_isRecording) {
      throw Exception('Already recording');
    }

    _isRecording = true;
    return await _analysisService.startRealTimeAnalysisWithRecording();
  }

  /// Stop real-time analysis and recording.
  Future<void> stopRealTimeAnalysis() async {
    await _analysisService.stopRealTimeAnalysisWithRecording();
    _isRecording = false;
  }

  AudioAnalysisService get analysisService => _analysisService;

  Future<void> dispose() async {
    await _playerStateSub?.cancel();
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    await _audioRecorder.dispose();
    await _ttsService.dispose();
    await _analysisService.dispose();
  }
}
