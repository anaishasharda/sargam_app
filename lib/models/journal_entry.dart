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
    );
  }
}
