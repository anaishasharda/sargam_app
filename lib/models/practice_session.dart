class PracticeSession {
  final DateTime date;
  final String raga;
  final String type;
  final List<MissedNote> missedNotes;
  final int tempo;
  final int pitchAccuracy;
  final int practiceTime;

  PracticeSession({
    required this.date,
    required this.raga,
    required this.type,
    required this.missedNotes,
    required this.tempo,
    required this.pitchAccuracy,
    required this.practiceTime,
  });
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
}
