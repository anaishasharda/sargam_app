class JournalEntry {
  final String? id;
  final String userId;
  final DateTime date;
  final String raga;
  final String sur;
  final String taal;
  final String type;
  final String notes;
  final int pitchAccuracy;
  final int practiceTime;

  final double? avgPitch;
  final double? avgVolume;
  final double? bpm;
  final List<String>? detectedNotes;
  final List<String>? missingNotesAI; // Missing swaras identified by AI
  final double? brightness;
  final double? stability;
  final String? aiFeedback; // Full AI textual feedback from Gemini

  JournalEntry({
    this.id,
    required this.userId,
    required this.date,
    required this.raga,
    required this.sur,
    required this.taal,
    required this.type,
    required this.notes,
    required this.pitchAccuracy,
    required this.practiceTime,
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
      'sur': sur,
      'taal': taal,
      'type': type,
      'notes': notes,
      'pitchAccuracy': pitchAccuracy,
      'practiceTime': practiceTime,
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

  factory JournalEntry.fromFirestore(Map<String, dynamic> data, String id) {
    return JournalEntry(
      id: id,
      userId: data['userId'] ?? '',
      date: DateTime.parse(data['date']),
      raga: data['raga'] ?? '',
      sur: data['sur'] ?? '',
      taal: data['taal'] ?? '',
      type: data['type'] ?? '',
      notes: data['notes'] ?? '',
      pitchAccuracy: data['pitchAccuracy'] ?? 0,
      practiceTime: data['practiceTime'] ?? 0,
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

  JournalEntry copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? raga,
    String? sur,
    String? taal,
    String? type,
    String? notes,
    int? pitchAccuracy,
    int? practiceTime,
    double? avgPitch,
    double? avgVolume,
    double? bpm,
    List<String>? detectedNotes,
    List<String>? missingNotesAI,
    double? brightness,
    double? stability,
    String? aiFeedback,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      raga: raga ?? this.raga,
      sur: sur ?? this.sur,
      taal: taal ?? this.taal,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      pitchAccuracy: pitchAccuracy ?? this.pitchAccuracy,
      practiceTime: practiceTime ?? this.practiceTime,
      avgPitch: avgPitch ?? this.avgPitch,
      avgVolume: avgVolume ?? this.avgVolume,
      bpm: bpm ?? this.bpm,
      detectedNotes: detectedNotes ?? this.detectedNotes,
      missingNotesAI: missingNotesAI ?? this.missingNotesAI,
      brightness: brightness ?? this.brightness,
      stability: stability ?? this.stability,
      aiFeedback: aiFeedback ?? this.aiFeedback,
    );
  }
}
