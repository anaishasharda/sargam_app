import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/practice_session.dart';
import '../models/journal_entry.dart';
import '../models/practice_goal.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collections
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _practiceSessionsCollection =>
      _firestore.collection('practice_sessions');
  CollectionReference get _journalEntriesCollection =>
      _firestore.collection('journal_entries');
  CollectionReference get _practiceGoalsCollection =>
      _firestore.collection('practice_goals');

  // User Profile Methods
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> createUserProfile(UserProfile userProfile) async {
    try {
      await _usersCollection.doc(userProfile.id).set(userProfile.toFirestore());
    } catch (e) {
      print('Error creating user profile: $e');
      throw e;
    }
  }

  Future<void> updateUserProfile(UserProfile userProfile) async {
    try {
      await _usersCollection
          .doc(userProfile.id)
          .update(userProfile.toFirestore());
    } catch (e) {
      print('Error updating user profile: $e');
      throw e;
    }
  }

  // Practice Session Methods
  Future<String> addPracticeSession(PracticeSession session) async {
    try {
      final docRef = await _practiceSessionsCollection.add(
        session.toFirestore(),
      );

      // Update user stats
      await _updateUserStatsAfterPractice(session);

      return docRef.id;
    } catch (e) {
      print('Error adding practice session: $e');
      throw e;
    }
  }

  Future<List<PracticeSession>> getPracticeSessions(
    String userId, {
    int? limit,
  }) async {
    try {
      Query query = _practiceSessionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => PracticeSession.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting practice sessions: $e');
      return [];
    }
  }

  Future<List<PracticeSession>> getPracticeSessionsByRaga(
    String userId,
    String raga,
  ) async {
    try {
      final querySnapshot = await _practiceSessionsCollection
          .where('userId', isEqualTo: userId)
          .where('raga', isEqualTo: raga)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => PracticeSession.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting practice sessions by raga: $e');
      return [];
    }
  }

  // Journal Entry Methods
  Future<String> addJournalEntry(JournalEntry entry) async {
    try {
      final docRef = await _journalEntriesCollection.add(entry.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding journal entry: $e');
      throw e;
    }
  }

  Future<List<JournalEntry>> getJournalEntries(
    String userId, {
    int? limit,
  }) async {
    try {
      Query query = _journalEntriesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => JournalEntry.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting journal entries: $e');
      return [];
    }
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    try {
      await _journalEntriesCollection.doc(entry.id).update(entry.toFirestore());
    } catch (e) {
      print('Error updating journal entry: $e');
      throw e;
    }
  }

  Future<void> deleteJournalEntry(String entryId) async {
    try {
      await _journalEntriesCollection.doc(entryId).delete();
    } catch (e) {
      print('Error deleting journal entry: $e');
      throw e;
    }
  }

  // Practice Goal Methods
  Future<String> addPracticeGoal(PracticeGoal goal) async {
    try {
      final docRef = await _practiceGoalsCollection.add(goal.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error adding practice goal: $e');
      throw e;
    }
  }

  Future<List<PracticeGoal>> getPracticeGoals(String userId) async {
    try {
      final querySnapshot = await _practiceGoalsCollection
          // .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map(
            (doc) => PracticeGoal.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      print('Error getting practice goals: $e');
      return [];
    }
  }

  Future<void> updatePracticeGoal(PracticeGoal goal) async {
    try {
      await _practiceGoalsCollection.doc(goal.id).update(goal.toFirestore());
    } catch (e) {
      print('Error updating practice goal: $e');
      throw e;
    }
  }

  Future<void> deletePracticeGoal(String goalId) async {
    try {
      await _practiceGoalsCollection.doc(goalId).delete();
    } catch (e) {
      print('Error deleting practice goal: $e');
      throw e;
    }
  }

  // Analytics Methods
  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    try {
      final sessions = await getPracticeSessions(userId);
      final goals = await getPracticeGoals(userId);

      if (sessions.isEmpty) {
        return {
          'totalPracticeTime': 0,
          'averagePitchAccuracy': 0.0,
          'practiceStreak': 0,
          'totalSessions': 0,
          'favoriteRaga': '',
          'ragaPracticeCount': <String, int>{},
          'completedGoals': 0,
          'activeGoals': 0,
        };
      }

      // Calculate total practice time
      final totalPracticeTime = sessions.fold<int>(
        0,
        (sum, session) => sum + session.practiceTime,
      );

      // Calculate average pitch accuracy
      final averagePitchAccuracy =
          sessions.fold<double>(
            0,
            (sum, session) => sum + session.pitchAccuracy,
          ) /
          sessions.length;

      // Calculate practice streak
      final practiceStreak = _calculatePracticeStreak(sessions);

      // Calculate raga practice count
      final ragaPracticeCount = <String, int>{};
      for (final session in sessions) {
        ragaPracticeCount[session.raga] =
            (ragaPracticeCount[session.raga] ?? 0) + 1;
      }

      // Find favorite raga
      String favoriteRaga = '';
      int maxCount = 0;
      ragaPracticeCount.forEach((raga, count) {
        if (count > maxCount) {
          maxCount = count;
          favoriteRaga = raga;
        }
      });

      // Count completed and active goals
      final completedGoals = goals.where((goal) => goal.isCompleted).length;
      final activeGoals = goals.where((goal) => !goal.isCompleted).length;

      return {
        'totalPracticeTime': totalPracticeTime,
        'averagePitchAccuracy': averagePitchAccuracy,
        'practiceStreak': practiceStreak,
        'totalSessions': sessions.length,
        'favoriteRaga': favoriteRaga,
        'ragaPracticeCount': ragaPracticeCount,
        'completedGoals': completedGoals,
        'activeGoals': activeGoals,
      };
    } catch (e) {
      print('Error getting user analytics: $e');
      return {};
    }
  }

  // Helper Methods
  Future<void> _updateUserStatsAfterPractice(PracticeSession session) async {
    try {
      final userId = session.userId;
      final userProfile = await getUserProfile(userId);

      if (userProfile != null) {
        final analytics = await getUserAnalytics(userId);

        final updatedProfile = userProfile.copyWith(
          totalPracticeTime: analytics['totalPracticeTime'],
          averagePitchAccuracy: analytics['averagePitchAccuracy'],
          practiceStreak: analytics['practiceStreak'],
          totalSessions: analytics['totalSessions'],
          favoriteRaga: analytics['favoriteRaga'],
          ragaPracticeCount: Map<String, int>.from(
            analytics['ragaPracticeCount'],
          ),
          lastPracticeDate: session.date,
        );

        await updateUserProfile(updatedProfile);
      }
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }

  int _calculatePracticeStreak(List<PracticeSession> sessions) {
    if (sessions.isEmpty) return 0;

    // Sort sessions by date (most recent first)
    sessions.sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime currentDate = DateTime.now();

    // Check if practiced today or yesterday
    final today = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    );
    final mostRecentPractice = DateTime(
      sessions.first.date.year,
      sessions.first.date.month,
      sessions.first.date.day,
    );

    if (today.difference(mostRecentPractice).inDays > 1) {
      return 0; // Streak broken
    }

    // Count consecutive days
    DateTime checkDate = today;
    for (final session in sessions) {
      final sessionDate = DateTime(
        session.date.year,
        session.date.month,
        session.date.day,
      );

      if (sessionDate.isAtSameMomentAs(checkDate) ||
          sessionDate.isAtSameMomentAs(
            checkDate.subtract(const Duration(days: 1)),
          )) {
        if (sessionDate.isAtSameMomentAs(
          checkDate.subtract(const Duration(days: 1)),
        )) {
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  // Authentication Methods
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        // Create user profile if it doesn't exist
        final existingProfile = await getUserProfile(user.uid);
        if (existingProfile == null) {
          final newProfile = UserProfile(
            id: user.uid,
            email: user.email ?? 'anonymous@riti.app',
            name: 'Anonymous User',
          );
          await createUserProfile(newProfile);
        }
      }

      return user;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Future<void> deleteAccountAndData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final userId = user.uid;
    try {
      await _deleteUserCollectionData(_practiceSessionsCollection, userId);
      await _deleteUserCollectionData(_journalEntriesCollection, userId);
      await _deleteUserCollectionData(_practiceGoalsCollection, userId);
      await _usersCollection.doc(userId).delete();

      await user.delete();
    } catch (e) {
      print('Error deleting account data: $e');
      rethrow;
    }
  }

  Future<void> _deleteUserCollectionData(
    CollectionReference collection,
    String userId,
  ) async {
    const batchSize = 450;

    while (true) {
      final snapshot = await collection
          .where('userId', isEqualTo: userId)
          .limit(batchSize)
          .get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (snapshot.docs.length < batchSize) {
        break;
      }
    }
  }
}
