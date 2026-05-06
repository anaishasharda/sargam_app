import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// One target note in a TargetTrack.
class TargetNote {
  final String sargam;
  final double startSec;
  final double endSec;
  final double freqHz;

  /// Semitone offset from base Sa (e.g. Re = 2, Pa = 7, Sa' = 12, ,Ni = -1).
  final int semitones;

  const TargetNote({
    required this.sargam,
    required this.startSec,
    required this.endSec,
    required this.freqHz,
    required this.semitones,
  });
}

/// Drives both the reference playback and the orange-bar timeline shown on
/// the sing-along graph.
class TargetTrack {
  final List<TargetNote> notes;
  final double totalDurationSec;
  final double baseSaHz;

  const TargetTrack({
    required this.notes,
    required this.totalDurationSec,
    required this.baseSaHz,
  });
}

/// Synthesizes alankar/sargam exercises in-memory and plays them via just_audio.
/// Tempo and transpose are runtime parameters — no pre-recorded files needed.
class ToneSynthService {
  static final ToneSynthService _instance = ToneSynthService._internal();
  factory ToneSynthService() => _instance;
  ToneSynthService._internal();

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  static const int _sampleRate = 44100;
  static const double _baseSaC4 = 261.63; // Hz at transpose 0

  /// Suddh-Bilawal scale (major). Token → semitones from Sa within octave.
  static const Map<String, int> _scale = {
    'Sa': 0,
    'Re': 2,
    'Ga': 4,
    'Ma': 5,
    'Pa': 7,
    'Dha': 9,
    'Ni': 11,
  };

  /// Strips octave markers and returns (base token, octave offset in semitones).
  static (String, int) _parseToken(String token) {
    var base = token;
    var octave = 0;
    while (base.endsWith("'")) {
      base = base.substring(0, base.length - 1);
      octave += 12;
    }
    while (base.startsWith(',')) {
      base = base.substring(1);
      octave -= 12;
    }
    return (base, octave);
  }

  /// Returns null if the token is not in the suddh-Bilawal scale.
  static int? semitonesFromSa(String token) {
    final (base, octave) = _parseToken(token);
    final inScale = _scale[base];
    return inScale == null ? null : inScale + octave;
  }

  static double baseSaFor(int transposeSemitones) {
    return _baseSaC4 * math.pow(2.0, transposeSemitones / 12.0);
  }

  static double frequencyFor(String token, int transposeSemitones) {
    final s = semitonesFromSa(token) ?? 0;
    return baseSaFor(transposeSemitones) * math.pow(2.0, s / 12.0);
  }

  /// Build a TargetTrack for [tokens] without playing audio. Useful when the
  /// caller wants the timeline before playback (e.g. to render the graph
  /// during preview).
  TargetTrack buildTrack({
    required List<String> tokens,
    required int bpm,
    required int transposeSemitones,
  }) {
    final secPerBeat = 60.0 / bpm;
    final baseSa = baseSaFor(transposeSemitones);
    final notes = <TargetNote>[];
    var t = 0.0;
    for (final token in tokens) {
      final s = semitonesFromSa(token) ?? 0;
      notes.add(TargetNote(
        sargam: token,
        startSec: t,
        endSec: t + secPerBeat,
        freqHz: baseSa * math.pow(2.0, s / 12.0),
        semitones: s,
      ));
      t += secPerBeat;
    }
    return TargetTrack(
      notes: notes,
      totalDurationSec: t,
      baseSaHz: baseSa,
    );
  }

  /// Synthesize [tokens] into a WAV temp file and start playing it.
  /// Returns the TargetTrack so the caller can drive the graph.
  Future<TargetTrack> playPattern({
    required List<String> tokens,
    required int bpm,
    required int transposeSemitones,
  }) async {
    final track = buildTrack(
      tokens: tokens,
      bpm: bpm,
      transposeSemitones: transposeSemitones,
    );
    final wavBytes = _synthesizeWav(track);

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/alankar_${DateTime.now().millisecondsSinceEpoch}.wav',
    );
    await file.writeAsBytes(wavBytes, flush: true);

    try {
      await _player.stop();
      await _player.setFilePath(file.path);
      // ignore: discarded_futures
      _player.play();
    } catch (e) {
      debugPrint('ToneSynthService.playPattern error: $e');
    }
    return track;
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
  }

  Uint8List _synthesizeWav(TargetTrack track) {
    final totalSamples = (track.totalDurationSec * _sampleRate).round();
    final pcm = Int16List(totalSamples);

    // 5 ms attack + 30 ms release per note to avoid clicks.
    final attackSamples = (0.005 * _sampleRate).round();

    for (final note in track.notes) {
      final start = (note.startSec * _sampleRate).round();
      final end = math.min(
        totalSamples,
        (note.endSec * _sampleRate).round(),
      );
      final noteLen = end - start;
      if (noteLen <= 0) continue;
      final releaseSamples = math.min(
        (0.03 * _sampleRate).round(),
        noteLen ~/ 4,
      );
      final omega = 2 * math.pi * note.freqHz / _sampleRate;

      for (int i = 0; i < noteLen; i++) {
        // Triangle-ish tone: fundamental + softer 3rd harmonic for body.
        final phase = omega * i;
        final sample = 0.6 * math.sin(phase) + 0.2 * math.sin(3 * phase);

        // Linear envelope.
        double env = 1.0;
        if (i < attackSamples) {
          env = i / attackSamples;
        } else if (i > noteLen - releaseSamples) {
          env = (noteLen - i) / releaseSamples;
        }

        final v = (sample * env * 0.7 * 32767).clamp(-32767.0, 32767.0);
        pcm[start + i] = v.toInt();
      }
    }

    return _wrapAsWav(pcm);
  }

  Uint8List _wrapAsWav(Int16List pcm) {
    final dataBytes = pcm.buffer.asUint8List();
    final dataSize = dataBytes.length;
    const headerSize = 44;
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
    writeU32(16); // PCM fmt subchunk size
    writeU16(1); // AudioFormat = PCM
    writeU16(1); // NumChannels = mono
    writeU32(_sampleRate);
    writeU32(_sampleRate * 2); // ByteRate = SR * NumCh * BitsPerSample/8
    writeU16(2); // BlockAlign
    writeU16(16); // BitsPerSample
    writeStr('data');
    writeU32(dataSize);
    out.add(dataBytes);

    return out.toBytes();
  }
}
