class UserProfile {
  final String? id;
  final String email;
  final String name;
  final String? profileImageUrl;
  final DateTime joinedDate;
  final int totalPracticeTime; // in minutes
  final int practiceStreak;
  final String favoriteRaga;
  final Map<String, int> ragaPracticeCount;
  final double averagePitchAccuracy;
  final int totalSessions;
  final DateTime lastPracticeDate;
  final double? baseSaHz;
  final DateTime? saCalibratedAt;
  final String? saConfidence;

  UserProfile({
    this.id,
    required this.email,
    required this.name,
    this.profileImageUrl,
    DateTime? joinedDate,
    this.totalPracticeTime = 0,
    this.practiceStreak = 0,
    this.favoriteRaga = '',
    Map<String, int>? ragaPracticeCount,
    this.averagePitchAccuracy = 0.0,
    this.totalSessions = 0,
    DateTime? lastPracticeDate,
    this.baseSaHz,
    this.saCalibratedAt,
    this.saConfidence,
  }) : joinedDate = joinedDate ?? DateTime.now(),
       ragaPracticeCount = ragaPracticeCount ?? {},
       lastPracticeDate = lastPracticeDate ?? DateTime.now();

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'joinedDate': joinedDate.toIso8601String(),
      'totalPracticeTime': totalPracticeTime,
      'practiceStreak': practiceStreak,
      'favoriteRaga': favoriteRaga,
      'ragaPracticeCount': ragaPracticeCount,
      'averagePitchAccuracy': averagePitchAccuracy,
      'totalSessions': totalSessions,
      'lastPracticeDate': lastPracticeDate.toIso8601String(),
      'baseSaHz': baseSaHz,
      'saCalibratedAt': saCalibratedAt?.toIso8601String(),
      'saConfidence': saConfidence,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String id) {
    return UserProfile(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      joinedDate: DateTime.parse(data['joinedDate']),
      totalPracticeTime: data['totalPracticeTime'] ?? 0,
      practiceStreak: data['practiceStreak'] ?? 0,
      favoriteRaga: data['favoriteRaga'] ?? '',
      ragaPracticeCount: Map<String, int>.from(data['ragaPracticeCount'] ?? {}),
      averagePitchAccuracy: (data['averagePitchAccuracy'] ?? 0.0).toDouble(),
      totalSessions: data['totalSessions'] ?? 0,
      lastPracticeDate: DateTime.parse(data['lastPracticeDate']),
      baseSaHz: (data['baseSaHz'] as num?)?.toDouble(),
      saCalibratedAt: data['saCalibratedAt'] != null
          ? DateTime.parse(data['saCalibratedAt'])
          : null,
      saConfidence: data['saConfidence'],
    );
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImageUrl,
    DateTime? joinedDate,
    int? totalPracticeTime,
    int? practiceStreak,
    String? favoriteRaga,
    Map<String, int>? ragaPracticeCount,
    double? averagePitchAccuracy,
    int? totalSessions,
    DateTime? lastPracticeDate,
    double? baseSaHz,
    DateTime? saCalibratedAt,
    String? saConfidence,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      joinedDate: joinedDate ?? this.joinedDate,
      totalPracticeTime: totalPracticeTime ?? this.totalPracticeTime,
      practiceStreak: practiceStreak ?? this.practiceStreak,
      favoriteRaga: favoriteRaga ?? this.favoriteRaga,
      ragaPracticeCount: ragaPracticeCount ?? this.ragaPracticeCount,
      averagePitchAccuracy: averagePitchAccuracy ?? this.averagePitchAccuracy,
      totalSessions: totalSessions ?? this.totalSessions,
      lastPracticeDate: lastPracticeDate ?? this.lastPracticeDate,
      baseSaHz: baseSaHz ?? this.baseSaHz,
      saCalibratedAt: saCalibratedAt ?? this.saCalibratedAt,
      saConfidence: saConfidence ?? this.saConfidence,
    );
  }
}

