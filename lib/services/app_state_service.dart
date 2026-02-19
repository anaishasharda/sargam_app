import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/practice_session.dart';
import '../models/journal_entry.dart';
import '../models/practice_goal.dart';
import 'firebase_service.dart';

class AppStateService extends ChangeNotifier {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  // State variables
  UserProfile? _currentUser;
  List<PracticeSession> _practiceSessions = [];
  List<JournalEntry> _journalEntries = [];
  List<PracticeGoal> _practiceGoals = [];
  Map<String, dynamic> _userAnalytics = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  UserProfile? get currentUser => _currentUser;
  List<PracticeSession> get practiceSessions => _practiceSessions;
  List<JournalEntry> get journalEntries => _journalEntries;
  List<PracticeGoal> get practiceGoals => _practiceGoals;
  Map<String, dynamic> get userAnalytics => _userAnalytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Initialize app state
  Future<void> initialize() async {
    _setLoading(true);
    try {
      // Check if user is already signed in
      final currentFirebaseUser = FirebaseAuth.instance.currentUser;

      if (currentFirebaseUser != null) {
        await _loadUserData(currentFirebaseUser.uid);
      } else {
        // Sign in anonymously for demo purposes
        // final user = await _firebaseService.signInAnonymously();
        // if (user != null) {
        //   await _loadUserData(user.uid);
        // }
      }
    } catch (e) {
      _setError('Failed to initialize app: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load user data
  Future<void> _loadUserData(String userId) async {
    try {
      // Load user profile
      _currentUser = await _firebaseService.getUserProfile(userId);

      // Load practice sessions
      _practiceSessions = await _firebaseService.getPracticeSessions(
        userId,
        limit: 50,
      );

      // Load journal entries
      _journalEntries = await _firebaseService.getJournalEntries(
        userId,
        limit: 20,
      );

      // Load practice goals
      _practiceGoals = await _firebaseService.getPracticeGoals(userId);

      // Load analytics
      _userAnalytics = await _firebaseService.getUserAnalytics(userId);

      notifyListeners();
    } catch (e) {
      _setError('Failed to load user data: $e');
    }
  }

  // Refresh data
  Future<void> refreshData() async {
    if (_currentUser?.id != null) {
      await _loadUserData(_currentUser!.id!);
    }
  }

  // Practice Session Methods
  Future<void> addPracticeSession(PracticeSession session) async {
    _setLoading(true);
    try {
      final sessionId = await _firebaseService.addPracticeSession(session);
      final newSession = PracticeSession(
        id: sessionId,
        userId: session.userId,
        date: session.date,
        raga: session.raga,
        type: session.type,
        missedNotes: session.missedNotes,
        tempo: session.tempo,
        pitchAccuracy: session.pitchAccuracy,
        practiceTime: session.practiceTime,
        overallAccuracy: session.overallAccuracy,
        tempoAccuracy: session.tempoAccuracy,
        rhythmAccuracy: session.rhythmAccuracy,
        avgPitch: session.avgPitch,
        avgVolume: session.avgVolume,
        bpm: session.bpm,
        detectedNotes: session.detectedNotes,
        brightness: session.brightness,
        stability: session.stability,
      );

      _practiceSessions.insert(0, newSession);

      // Refresh analytics and user profile
      await refreshData();

      _clearError();
    } catch (e) {
      _setError('Failed to add practice session: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Journal Entry Methods
  Future<void> addJournalEntry(JournalEntry entry) async {
    _setLoading(true);
    try {
      final entryId = await _firebaseService.addJournalEntry(entry);
      final newEntry = JournalEntry(
        id: entryId,
        userId: entry.userId,
        date: entry.date,
        raga: entry.raga,
        sur: entry.sur,
        taal: entry.taal,
        type: entry.type,
        notes: entry.notes,
        pitchAccuracy: entry.pitchAccuracy,
        practiceTime: entry.practiceTime,
        avgPitch: entry.avgPitch,
        avgVolume: entry.avgVolume,
        bpm: entry.bpm,
        detectedNotes: entry.detectedNotes,
        brightness: entry.brightness,
        stability: entry.stability,
      );

      _journalEntries.insert(0, newEntry);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add journal entry: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    _setLoading(true);
    try {
      await _firebaseService.updateJournalEntry(entry);

      final index = _journalEntries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _journalEntries[index] = entry;
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to update journal entry: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteJournalEntry(String entryId) async {
    _setLoading(true);
    try {
      await _firebaseService.deleteJournalEntry(entryId);
      _journalEntries.removeWhere((entry) => entry.id == entryId);

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete journal entry: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Practice Goal Methods
  Future<void> addPracticeGoal(PracticeGoal goal) async {
    _setLoading(true);
    try {
      final goalId = await _firebaseService.addPracticeGoal(goal);
      final newGoal = goal.copyWith(id: goalId);

      _practiceGoals.insert(0, newGoal);
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add practice goal: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updatePracticeGoal(PracticeGoal goal) async {
    _setLoading(true);
    try {
      await _firebaseService.updatePracticeGoal(goal);

      final index = _practiceGoals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _practiceGoals[index] = goal;
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to update practice goal: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deletePracticeGoal(String goalId) async {
    _setLoading(true);
    try {
      await _firebaseService.deletePracticeGoal(goalId);
      _practiceGoals.removeWhere((goal) => goal.id == goalId);

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete practice goal: $e');
    } finally {
      _setLoading(false);
    }
  }

  // User Profile Methods
  Future<void> updateUserProfile(UserProfile profile) async {
    _setLoading(true);
    try {
      await _firebaseService.updateUserProfile(profile);
      _currentUser = profile;

      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to update user profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Helper Methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Get practice sessions by raga
  List<PracticeSession> getPracticeSessionsByRaga(String raga) {
    return _practiceSessions.where((session) => session.raga == raga).toList();
  }

  // Get recent practice sessions
  List<PracticeSession> getRecentPracticeSessions({int limit = 10}) {
    final sessions = List<PracticeSession>.from(_practiceSessions);
    sessions.sort((a, b) => b.date.compareTo(a.date));
    return sessions.take(limit).toList();
  }

  // Get active goals
  List<PracticeGoal> getActiveGoals() {
    return _practiceGoals.where((goal) => !goal.isCompleted).toList();
  }

  // Get completed goals
  List<PracticeGoal> getCompletedGoals() {
    return _practiceGoals.where((goal) => goal.isCompleted).toList();
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseService.signOut();
    _currentUser = null;
    _practiceSessions.clear();
    _journalEntries.clear();
    _practiceGoals.clear();
    _userAnalytics.clear();
    _clearError();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      await _firebaseService.deleteAccountAndData();
      _currentUser = null;
      _practiceSessions.clear();
      _journalEntries.clear();
      _practiceGoals.clear();
      _userAnalytics.clear();
      _clearError();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete account: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAccountWithPassword(String password) async {
    _setLoading(true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;
      if (user == null || email == null) {
        _setError('No authenticated user found.');
        return false;
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      await _firebaseService.deleteAccountAndData();
      _currentUser = null;
      _practiceSessions.clear();
      _journalEntries.clear();
      _practiceGoals.clear();
      _userAnalytics.clear();
      _clearError();
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Failed to reauthenticate user.');
      return false;
    } catch (e) {
      _setError('Failed to delete account: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
