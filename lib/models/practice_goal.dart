class PracticeGoal {
  final String? id;
  final String userId;
  final String title;
  final String description;
  final int targetDays;
  int completedDays;
  final String raga;
  final DateTime deadline;
  final DateTime createdAt;
  final bool isCompleted;

  PracticeGoal({
    this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.targetDays,
    required this.completedDays,
    required this.raga,
    required this.deadline,
    DateTime? createdAt,
    bool? isCompleted,
  }) : createdAt = createdAt ?? DateTime.now(),
       isCompleted = isCompleted ?? false;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'targetDays': targetDays,
      'completedDays': completedDays,
      'raga': raga,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  factory PracticeGoal.fromFirestore(Map<String, dynamic> data, String id) {
    return PracticeGoal(
      id: id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetDays: data['targetDays'] ?? 0,
      completedDays: data['completedDays'] ?? 0,
      raga: data['raga'] ?? '',
      deadline: DateTime.parse(data['deadline']),
      createdAt: DateTime.parse(data['createdAt']),
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  PracticeGoal copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? targetDays,
    int? completedDays,
    String? raga,
    DateTime? deadline,
    DateTime? createdAt,
    bool? isCompleted,
  }) {
    return PracticeGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDays: targetDays ?? this.targetDays,
      completedDays: completedDays ?? this.completedDays,
      raga: raga ?? this.raga,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
