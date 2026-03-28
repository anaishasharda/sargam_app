class PracticeSession {
  final String? id;
  final String userId;
  final DateTime date;
  final String raga;
  final String type;
  final List<MissedNote> missedNotes;
  final int tempo;
  final int pitchAccuracy;
  final int practiceTime;
  final double? overallAccuracy;
  final double? tempoAccuracy;
  final double? rhythmAccuracy;

  final double? avgPitch;
  final double? avgVolume;
  final double? bpm;
  final List<String>? detectedNotes;
  final List<String>? missingNotesAI; // Simple swara name list from AI
  final double? brightness;
  final double? stability;
  final String? aiFeedback; // Full AI textual feedback from Gemini

  PracticeSession({
    this.id,
    required this.userId,
    required this.date,
    required this.raga,
    required this.type,
    required this.missedNotes,
    required this.tempo,
    required this.pitchAccuracy,
    required this.practiceTime,
    this.overallAccuracy,
    this.tempoAccuracy,
    this.rhythmAccuracy,
    this.avgPitch,
    this.avgVolume,
    this.bpm,
    this.detectedNotes,
    this.missingNotesAI,
    this.brightness,
    this.stability,
    this.aiFeedback,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': date.toIso8601String(),
      'raga': raga,
      'type': type,
      'missedNotes': missedNotes.map((note) => note.toFirestore()).toList(),
      'tempo': tempo,
      'pitchAccuracy': pitchAccuracy,
      'practiceTime': practiceTime,
      'overallAccuracy': overallAccuracy,
      'tempoAccuracy': tempoAccuracy,
      'rhythmAccuracy': rhythmAccuracy,
      'avgPitch': avgPitch,
      'avgVolume': avgVolume,
      'bpm': bpm,
      'detectedNotes': detectedNotes,
      'missingNotesAI': missingNotesAI,
      'brightness': brightness,
      'stability': stability,
      'aiFeedback': aiFeedback,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  factory PracticeSession.fromFirestore(Map<String, dynamic> data, String id) {
    return PracticeSession(
      id: id,
      userId: data['userId'] ?? '',
      date: DateTime.parse(data['date']),
      raga: data['raga'] ?? '',
      type: data['type'] ?? '',
      missedNotes:
          (data['missedNotes'] as List<dynamic>?)
              ?.map((note) => MissedNote.fromFirestore(note))
              .toList() ??
          [],
      tempo: data['tempo'] ?? 0,
      pitchAccuracy: data['pitchAccuracy'] ?? 0,
      practiceTime: data['practiceTime'] ?? 0,
      overallAccuracy: data['overallAccuracy']?.toDouble(),
      tempoAccuracy: data['tempoAccuracy']?.toDouble(),
      rhythmAccuracy: data['rhythmAccuracy']?.toDouble(),
      avgPitch: data['avgPitch']?.toDouble(),
      avgVolume: data['avgVolume']?.toDouble(),
      bpm: data['bpm']?.toDouble(),
      detectedNotes: data['detectedNotes'] != null
          ? List<String>.from(data['detectedNotes'])
          : null,
      missingNotesAI: data['missingNotesAI'] != null
          ? List<String>.from(data['missingNotesAI'])
          : null,
      brightness: data['brightness']?.toDouble(),
      stability: data['stability']?.toDouble(),
      aiFeedback: data['aiFeedback'] as String?,
    );
  }
}

class MissedNote {
  final String note;
  final int count;
  final String expectedPitch;
  final String actualPitch;

  MissedNote({
    required this.note,
    required this.count,
    required this.expectedPitch,
    required this.actualPitch,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'note': note,
      'count': count,
      'expectedPitch': expectedPitch,
      'actualPitch': actualPitch,
    };
  }

  factory MissedNote.fromFirestore(Map<String, dynamic> data) {
    return MissedNote(
      note: data['note'] ?? '',
      count: data['count'] ?? 0,
      expectedPitch: data['expectedPitch'] ?? '',
      actualPitch: data['actualPitch'] ?? '',
    );
  }
}
