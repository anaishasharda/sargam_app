import 'dart:math' as math;

class AudioCharacteristics {
  final double pitch; // Frequency in Hz
  final double tempo; // Beats per minute
  final List<double> rhythm; // Rhythm pattern (time intervals)
  final List<String> notes; // Detected musical notes
  final double volume; // RMS volume level
  final List<double> spectrum; // Frequency spectrum
  final double duration; // Duration in seconds
  final List<double> pitchTrajectory; // Sequence of pitches over time windows

  const AudioCharacteristics({
    required this.pitch,
    required this.tempo,
    required this.rhythm,
    required this.notes,
    required this.volume,
    required this.spectrum,
    required this.duration,
    this.pitchTrajectory = const [],
  });

  /// Create a copy with updated values
  AudioCharacteristics copyWith({
    double? pitch,
    double? tempo,
    List<double>? rhythm,
    List<String>? notes,
    double? volume,
    List<double>? spectrum,
    double? duration,
    List<double>? pitchTrajectory,
  }) {
    return AudioCharacteristics(
      pitch: pitch ?? this.pitch,
      tempo: tempo ?? this.tempo,
      rhythm: rhythm ?? this.rhythm,
      notes: notes ?? this.notes,
      volume: volume ?? this.volume,
      spectrum: spectrum ?? this.spectrum,
      duration: duration ?? this.duration,
      pitchTrajectory: pitchTrajectory ?? this.pitchTrajectory,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'pitch': pitch,
      'tempo': tempo,
      'rhythm': rhythm,
      'notes': notes,
      'volume': volume,
      'spectrum': spectrum,
      'duration': duration,
      'pitchTrajectory': pitchTrajectory,
    };
  }

  /// Create from map
  factory AudioCharacteristics.fromMap(Map<String, dynamic> map) {
    return AudioCharacteristics(
      pitch: map['pitch']?.toDouble() ?? 0.0,
      tempo: map['tempo']?.toDouble() ?? 0.0,
      rhythm: List<double>.from(map['rhythm'] ?? []),
      notes: List<String>.from(map['notes'] ?? []),
      volume: map['volume']?.toDouble() ?? 0.0,
      spectrum: List<double>.from(map['spectrum'] ?? []),
      duration: map['duration']?.toDouble() ?? 0.0,
      pitchTrajectory: List<double>.from(map['pitchTrajectory'] ?? []),
    );
  }

  /// Get dominant frequency from spectrum
  double get dominantFrequency {
    if (spectrum.isEmpty) return 0.0;

    int maxIndex = 0;
    double maxValue = spectrum[0];

    for (int i = 1; i < spectrum.length; i++) {
      if (spectrum[i] > maxValue) {
        maxValue = spectrum[i];
        maxIndex = i;
      }
    }

    // Convert index to frequency (assuming 44.1kHz sample rate)
    return (maxIndex * 44100.0) / (spectrum.length * 2);
  }

  /// Get frequency range
  Map<String, double> get frequencyRange {
    if (spectrum.isEmpty) return {'min': 0.0, 'max': 0.0};

    double minFreq = double.infinity;
    double maxFreq = 0.0;

    for (int i = 0; i < spectrum.length; i++) {
      if (spectrum[i] > 0.01) {
        // Threshold for significant frequency
        final freq = (i * 44100.0) / (spectrum.length * 2);
        minFreq = minFreq < freq ? minFreq : freq;
        maxFreq = maxFreq > freq ? maxFreq : freq;
      }
    }

    return {'min': minFreq == double.infinity ? 0.0 : minFreq, 'max': maxFreq};
  }

  /// Get rhythm complexity (standard deviation of rhythm intervals)
  double get rhythmComplexity {
    if (rhythm.length < 2) return 0.0;

    final mean = rhythm.reduce((a, b) => a + b) / rhythm.length;
    final variance =
        rhythm.map((r) => (r - mean) * (r - mean)).reduce((a, b) => a + b) /
        rhythm.length;

    return math.sqrt(variance);
  }

  /// Get spectral centroid (brightness of sound)
  double get spectralCentroid {
    if (spectrum.isEmpty) return 0.0;

    double weightedSum = 0.0;
    double magnitudeSum = 0.0;

    for (int i = 0; i < spectrum.length; i++) {
      final freq = (i * 44100.0) / (spectrum.length * 2);
      weightedSum += freq * spectrum[i];
      magnitudeSum += spectrum[i];
    }

    return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0;
  }

  /// Get zero crossing rate (indicates noisiness)
  double get zeroCrossingRate {
    if (spectrum.isEmpty) return 0.0;

    int crossings = 0;
    for (int i = 1; i < spectrum.length; i++) {
      if ((spectrum[i] >= 0) != (spectrum[i - 1] >= 0)) {
        crossings++;
      }
    }

    return crossings / spectrum.length;
  }

  /// Check if audio is silent
  bool get isSilent => volume < 0.01;

  /// Check if audio has good quality
  bool get hasGoodQuality => volume > 0.01 && pitch > 0 && tempo > 0;

  /// Get audio quality score (0-100)
  double get qualityScore {
    double score = 0.0;

    // Volume score (0-30)
    score += (volume * 30).clamp(0.0, 30.0);

    // Pitch score (0-30)
    if (pitch > 0) score += 30.0;

    // Tempo score (0-20)
    if (tempo > 0) score += 20.0;

    // Rhythm score (0-20)
    if (rhythm.isNotEmpty) score += 20.0;

    return score;
  }

  @override
  String toString() {
    return 'AudioCharacteristics(pitch: $pitch Hz, tempo: $tempo BPM, notes: $notes, volume: ${(volume * 100).toStringAsFixed(1)}%, duration: ${duration.toStringAsFixed(2)}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioCharacteristics &&
        other.pitch == pitch &&
        other.tempo == tempo &&
        other.volume == volume &&
        other.duration == duration &&
        other.notes.length == notes.length &&
        other.rhythm.length == rhythm.length &&
        other.spectrum.length == spectrum.length &&
        other.pitchTrajectory.length == pitchTrajectory.length;
  }

  @override
  int get hashCode {
    return pitch.hashCode ^
        tempo.hashCode ^
        volume.hashCode ^
        duration.hashCode ^
        notes.hashCode ^
        rhythm.hashCode ^
        spectrum.hashCode ^
        pitchTrajectory.hashCode;
  }
}
