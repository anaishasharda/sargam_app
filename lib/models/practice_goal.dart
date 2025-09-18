class PracticeGoal {
  final String title;
  final String description;
  final int targetDays;
  int completedDays;
  final String raga;
  final DateTime deadline;

  PracticeGoal({
    required this.title,
    required this.description,
    required this.targetDays,
    required this.completedDays,
    required this.raga,
    required this.deadline,
  });
}
