import 'dart:convert';

class AIFeedbackResult {
  final double pitch;
  final double tempo;
  final double brightness;
  final double stability;
  final double duration;
  final List<String> detectedNotes;
  final List<String> missingNotes;
  final String feedback;

  const AIFeedbackResult({
    required this.pitch,
    required this.tempo,
    required this.brightness,
    required this.stability,
    required this.duration,
    required this.detectedNotes,
    required this.missingNotes,
    required this.feedback,
  });

  factory AIFeedbackResult.fromMap(Map<String, dynamic> map) {
    return AIFeedbackResult(
      pitch: (map['pitch'] as num?)?.toDouble() ?? 0.0,
      tempo: (map['tempo'] as num?)?.toDouble() ?? 0.0,
      brightness: (map['brightness'] as num?)?.toDouble() ?? 0.0,
      stability: (map['stability'] as num?)?.toDouble() ?? 0.0,
      duration: (map['duration'] as num?)?.toDouble() ?? 0.0,
      detectedNotes: List<String>.from(map['detectedNotes'] ?? []),
      missingNotes: List<String>.from(map['missingNotes'] ?? []),
      feedback: map['feedback'] as String? ?? 'No feedback provided.',
    );
  }

  factory AIFeedbackResult.fromJson(String source) =>
      AIFeedbackResult.fromMap(json.decode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    return {
      'pitch': pitch,
      'tempo': tempo,
      'brightness': brightness,
      'stability': stability,
      'duration': duration,
      'detectedNotes': detectedNotes,
      'missingNotes': missingNotes,
      'feedback': feedback,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'AIFeedbackResult(pitch: $pitch, tempo: $tempo, brightness: $brightness, stability: $stability, duration: $duration, detectedNotes: $detectedNotes, missingNotes: $missingNotes, feedback: $feedback)';
  }
}
