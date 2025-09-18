class JournalEntry {
  final DateTime date;
  final String raga;
  final String sur;
  final String taal;
  final String type;
  final String notes;
  final int pitchAccuracy;
  final int practiceTime;

  JournalEntry({
    required this.date,
    required this.raga,
    required this.sur,
    required this.taal,
    required this.type,
    required this.notes,
    required this.pitchAccuracy,
    required this.practiceTime,
  });
}
