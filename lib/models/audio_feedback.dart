import 'audio_characteristics.dart';

class AudioFeedback {
  final double pitchAccuracy;
  final double tempoAccuracy;
  final double rhythmAccuracy;
  final double overallAccuracy;
  final List<String> missedNotes;
  final List<String> suggestions;
  final String overallFeedback;
  final AudioCharacteristics? characteristics;

  AudioFeedback({
    required this.pitchAccuracy,
    required this.tempoAccuracy,
    required this.rhythmAccuracy,
    required this.overallAccuracy,
    required this.missedNotes,
    required this.suggestions,
    required this.overallFeedback,
    this.characteristics,
  });

  /// Create a copy with updated values
  AudioFeedback copyWith({
    double? pitchAccuracy,
    double? tempoAccuracy,
    double? rhythmAccuracy,
    double? overallAccuracy,
    List<String>? missedNotes,
    List<String>? suggestions,
    String? overallFeedback,
    AudioCharacteristics? characteristics,
  }) {
    return AudioFeedback(
      pitchAccuracy: pitchAccuracy ?? this.pitchAccuracy,
      tempoAccuracy: tempoAccuracy ?? this.tempoAccuracy,
      rhythmAccuracy: rhythmAccuracy ?? this.rhythmAccuracy,
      overallAccuracy: overallAccuracy ?? this.overallAccuracy,
      missedNotes: missedNotes ?? this.missedNotes,
      suggestions: suggestions ?? this.suggestions,
      overallFeedback: overallFeedback ?? this.overallFeedback,
      characteristics: characteristics ?? this.characteristics,
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'pitchAccuracy': pitchAccuracy,
      'tempoAccuracy': tempoAccuracy,
      'rhythmAccuracy': rhythmAccuracy,
      'overallAccuracy': overallAccuracy,
      'missedNotes': missedNotes,
      'suggestions': suggestions,
      'overallFeedback': overallFeedback,
      'characteristics': characteristics?.toMap(),
    };
  }

  /// Create from map
  factory AudioFeedback.fromMap(Map<String, dynamic> map) {
    return AudioFeedback(
      pitchAccuracy: map['pitchAccuracy']?.toDouble() ?? 0.0,
      tempoAccuracy: map['tempoAccuracy']?.toDouble() ?? 0.0,
      rhythmAccuracy: map['rhythmAccuracy']?.toDouble() ?? 0.0,
      overallAccuracy: map['overallAccuracy']?.toDouble() ?? 0.0,
      missedNotes: List<String>.from(map['missedNotes'] ?? []),
      suggestions: List<String>.from(map['suggestions'] ?? []),
      overallFeedback: map['overallFeedback'] ?? '',
      characteristics: map['characteristics'] != null
          ? AudioCharacteristics.fromMap(map['characteristics'])
          : null,
    );
  }

  /// Get performance grade (A, B, C, D, F)
  String get performanceGrade {
    if (overallAccuracy >= 90) return 'A';
    if (overallAccuracy >= 80) return 'B';
    if (overallAccuracy >= 70) return 'C';
    if (overallAccuracy >= 60) return 'D';
    return 'F';
  }

  /// Get performance level description
  String get performanceLevel {
    if (overallAccuracy >= 90) return 'Excellent';
    if (overallAccuracy >= 80) return 'Good';
    if (overallAccuracy >= 70) return 'Fair';
    if (overallAccuracy >= 60) return 'Needs Improvement';
    return 'Poor';
  }

  /// Check if performance is passing
  bool get isPassing => overallAccuracy >= 70;

  /// Get improvement areas
  List<String> get improvementAreas {
    final areas = <String>[];

    if (pitchAccuracy < 70) areas.add('Pitch Accuracy');
    if (tempoAccuracy < 70) areas.add('Tempo Accuracy');
    if (rhythmAccuracy < 70) areas.add('Rhythm Accuracy');

    return areas;
  }

  @override
  String toString() {
    return 'AudioFeedback(pitch: ${pitchAccuracy.toStringAsFixed(1)}%, tempo: ${tempoAccuracy.toStringAsFixed(1)}%, rhythm: ${rhythmAccuracy.toStringAsFixed(1)}%, overall: ${overallAccuracy.toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioFeedback &&
        other.pitchAccuracy == pitchAccuracy &&
        other.tempoAccuracy == tempoAccuracy &&
        other.rhythmAccuracy == rhythmAccuracy &&
        other.overallAccuracy == overallAccuracy &&
        other.missedNotes.length == missedNotes.length &&
        other.suggestions.length == suggestions.length &&
        other.overallFeedback == overallFeedback;
  }

  @override
  int get hashCode {
    return pitchAccuracy.hashCode ^
        tempoAccuracy.hashCode ^
        rhythmAccuracy.hashCode ^
        overallAccuracy.hashCode ^
        missedNotes.hashCode ^
        suggestions.hashCode ^
        overallFeedback.hashCode;
  }
}
