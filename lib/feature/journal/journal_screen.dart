import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/journal_entry.dart';
import '../../models/practice_session.dart';
import '../../services/ai_analysis_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AIAnalysisService _aiAnalysisService = AIAnalysisService();

  List<JournalEntry> _journalEntries = [];
  List<PracticeSession> _practiceSessions = [];
  List<_PracticeSnapshot> _practiceSnapshots = [];
  _PracticeDashboardMetrics? _dashboardMetrics;
  PracticeProgressAnalysis? _cachedAnalysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJournalData();
  }

  Future<void> _loadJournalData() async {
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        _firestore
            .collection('journal_entries')
            .where('userId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .get(),
        _firestore
            .collection('practice_sessions')
            .where('userId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .get(),
      ]);

      final journalSnapshot = results[0];
      final practiceSnapshot = results[1];

      final journalEntries = journalSnapshot.docs
          .map((doc) => JournalEntry.fromFirestore(doc.data(), doc.id))
          .toList();
      final practiceSessions = practiceSnapshot.docs
          .map((doc) => PracticeSession.fromFirestore(doc.data(), doc.id))
          .toList();
      final snapshots = _buildSnapshots(
        practiceSessions: practiceSessions,
        journalEntries: journalEntries,
      );

      if (!mounted) return;
      setState(() {
        _journalEntries = journalEntries;
        _practiceSessions = practiceSessions;
        _practiceSnapshots = snapshots;
        _dashboardMetrics = _computeDashboardMetrics(snapshots);
        _cachedAnalysis = null;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading journal data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<_PracticeSnapshot> _buildSnapshots({
    required List<PracticeSession> practiceSessions,
    required List<JournalEntry> journalEntries,
  }) {
    // Merge BOTH sources into one unified chronological list
    final List<_PracticeSnapshot> merged = [];

    for (final session in practiceSessions) {
      merged.add(
        _PracticeSnapshot(
          date: session.date,
          raga: session.raga,
          type: session.type,
          practiceTime: session.practiceTime,
          pitchAccuracy: session.pitchAccuracy,
          stability: session.stability,
          brightness: session.brightness,
          bpm: session.bpm ?? session.tempo.toDouble(),
          detectedNotes: session.detectedNotes,
          missingNotesAI: session.missingNotesAI,
          aiFeedback: session.aiFeedback,
          notes: null,
          source: 'practice_session',
        ),
      );
    }

    for (final entry in journalEntries) {
      merged.add(
        _PracticeSnapshot(
          date: entry.date,
          raga: entry.raga,
          type: entry.type,
          practiceTime: entry.practiceTime,
          pitchAccuracy: entry.pitchAccuracy,
          stability: entry.stability,
          brightness: entry.brightness,
          bpm: entry.bpm,
          detectedNotes: entry.detectedNotes,
          missingNotesAI: entry.missingNotesAI,
          aiFeedback: entry.aiFeedback,
          notes: entry.notes.isNotEmpty ? entry.notes : null,
          source: 'journal_entry',
          entryId: entry.id,
        ),
      );
    }

    merged.sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }

  _PracticeDashboardMetrics? _computeDashboardMetrics(
    List<_PracticeSnapshot> snapshots,
  ) {
    if (snapshots.isEmpty) return null;

    final totalMinutes = snapshots.fold<int>(
      0,
      (sum, item) => sum + item.practiceTime,
    );
    final averageAccuracy =
        snapshots.fold<double>(0, (sum, item) => sum + item.pitchAccuracy) /
        snapshots.length;

    final stabilityValues = snapshots
        .where((item) => item.stability != null)
        .map((item) => item.stability!)
        .toList();
    final brightnessValues = snapshots
        .where((item) => item.brightness != null)
        .map((item) => item.brightness!)
        .toList();
    final weeklyMinutes = snapshots
        .where((item) => DateTime.now().difference(item.date).inDays < 7)
        .fold<int>(0, (sum, item) => sum + item.practiceTime);

    final ragaCounts = <String, int>{};
    for (final snapshot in snapshots) {
      ragaCounts[snapshot.raga] = (ragaCounts[snapshot.raga] ?? 0) + 1;
    }

    String focusRaga = snapshots.first.raga;
    int focusRagaCount = 0;
    ragaCounts.forEach((raga, count) {
      if (count > focusRagaCount) {
        focusRaga = raga;
        focusRagaCount = count;
      }
    });

    final recentWindow = snapshots.take(5).toList();
    final previousWindow = snapshots.skip(5).take(5).toList();
    final recentAverage = recentWindow.isEmpty
        ? averageAccuracy
        : recentWindow.fold<double>(
                0,
                (sum, item) => sum + item.pitchAccuracy,
              ) /
              recentWindow.length;
    final previousAverage = previousWindow.isEmpty
        ? recentAverage
        : previousWindow.fold<double>(
                0,
                (sum, item) => sum + item.pitchAccuracy,
              ) /
              previousWindow.length;
    final delta = recentAverage - previousAverage;

    String trendLabel = 'Steady';
    Color trendColor = Colors.blueAccent;
    if (delta >= 4) {
      trendLabel = 'Improving';
      trendColor = Colors.greenAccent;
    } else if (delta <= -4) {
      trendLabel = 'Needs focus';
      trendColor = Colors.orangeAccent;
    }

    return _PracticeDashboardMetrics(
      totalSessions: snapshots.length,
      totalMinutes: totalMinutes,
      averageAccuracy: averageAccuracy,
      practiceStreak: _calculatePracticeStreak(snapshots),
      averageStability: stabilityValues.isEmpty
          ? null
          : stabilityValues.fold<double>(0, (sum, item) => sum + item) /
                stabilityValues.length,
      averageBrightness: brightnessValues.isEmpty
          ? null
          : brightnessValues.fold<double>(0, (sum, item) => sum + item) /
                brightnessValues.length,
      weeklyMinutes: weeklyMinutes,
      focusRaga: focusRaga,
      trendLabel: trendLabel,
      trendColor: trendColor,
      recentAverageAccuracy: recentAverage,
    );
  }

  int _calculatePracticeStreak(List<_PracticeSnapshot> snapshots) {
    if (snapshots.isEmpty) return 0;

    final uniqueDays =
        snapshots
            .map(
              (snapshot) => DateTime(
                snapshot.date.year,
                snapshot.date.month,
                snapshot.date.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final firstDay = uniqueDays.first;
    if (normalizedToday.difference(firstDay).inDays > 1) {
      return 0;
    }

    var streak = 1;
    for (var i = 1; i < uniqueDays.length; i++) {
      final gap = uniqueDays[i - 1].difference(uniqueDays[i]).inDays;
      if (gap == 1) {
        streak++;
      } else if (gap > 1) {
        break;
      }
    }

    return streak;
  }

  Future<void> _addJournalEntry(JournalEntry entry) async {
    try {
      await _firestore.collection('journal_entries').add(entry.toFirestore());
      await _loadJournalData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding journal entry: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateJournalEntry(JournalEntry entry) async {
    try {
      await _firestore
          .collection('journal_entries')
          .doc(entry.id)
          .update(entry.toFirestore());
      await _loadJournalData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating journal entry: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteJournalEntry(String entryId) async {
    try {
      await _firestore.collection('journal_entries').doc(entryId).delete();
      await _loadJournalData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting journal entry: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<PracticeProgressAnalysis> _loadDetailedAnalysis({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedAnalysis != null) {
      return _cachedAnalysis!;
    }

    if (_dashboardMetrics == null || _practiceSnapshots.isEmpty) {
      return PracticeProgressAnalysis.fallback(
        'Log a few practice sessions to unlock a detailed progress analysis.',
      );
    }

    final analysis = await _aiAnalysisService.getPracticeProgressAnalysis(
      summaryMetrics: {
        'total_sessions': _dashboardMetrics!.totalSessions,
        'total_minutes': _dashboardMetrics!.totalMinutes,
        'weekly_minutes': _dashboardMetrics!.weeklyMinutes,
        'average_pitch_accuracy': _dashboardMetrics!.averageAccuracy
            .toStringAsFixed(1),
        'recent_average_pitch_accuracy': _dashboardMetrics!
            .recentAverageAccuracy
            .toStringAsFixed(1),
        'practice_streak_days': _dashboardMetrics!.practiceStreak,
        'focus_raga': _dashboardMetrics!.focusRaga,
        'average_stability': _dashboardMetrics!.averageStability
            ?.toStringAsFixed(1),
        'average_brightness': _dashboardMetrics!.averageBrightness
            ?.toStringAsFixed(1),
        'data_source': _practiceSessions.isNotEmpty
            ? 'practice_sessions'
            : 'journal_entries',
      },
      recentSessions: _practiceSnapshots
          .take(10)
          .map((snapshot) => snapshot.toAnalysisMap())
          .toList(),
    );

    _cachedAnalysis = analysis;
    return analysis;
  }

  Future<void> _showProgressAnalysisDialog() async {
    if (_practiceSnapshots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add some practice history first to view analysis.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF19112D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Practice Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showProgressAnalysisDialog();
                  _loadDetailedAnalysis(forceRefresh: true);
                },
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<PracticeProgressAnalysis>(
              future: _loadDetailedAnalysis(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                  );
                }

                final analysis =
                    snapshot.data ??
                    PracticeProgressAnalysis.fallback(
                      'Detailed analysis is not available right now.',
                    );

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAnalysisSection('Summary', [analysis.summary]),
                      const SizedBox(height: 16),
                      _buildAnalysisChip(analysis.overallTrend),
                      const SizedBox(height: 20),
                      _buildAnalysisSection('Strengths', analysis.strengths),
                      const SizedBox(height: 16),
                      _buildAnalysisSection(
                        'Improve Next',
                        analysis.improvements,
                      ),
                      const SizedBox(height: 16),
                      _buildAnalysisSection(
                        'Practice Plan',
                        analysis.nextSteps,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Practice Journal',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your daily progress and practice sessions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 20),
                _buildProgressDashboard(),
                const SizedBox(height: 16),
                _buildQuickRecordCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
        else if (_practiceSnapshots.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note_outlined,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No practice history yet',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete a practice session or add a journal entry\nto see your progress here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.builder(
              itemCount: _practiceSnapshots.length,
              itemBuilder: (context, index) {
                final snapshot = _practiceSnapshots[index];
                return _buildSnapshotCard(snapshot);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProgressDashboard() {
    if (_isLoading) {
      return _buildDashboardShell(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    final metrics = _dashboardMetrics;
    if (metrics == null) {
      return _buildDashboardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your practice insights will appear here after a few logged sessions.',
              style: TextStyle(color: Colors.white.withOpacity(0.75)),
            ),
          ],
        ),
      );
    }

    return _buildDashboardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: metrics.trendColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: metrics.trendColor.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  metrics.trendLabel,
                  style: TextStyle(
                    color: metrics.trendColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Brief view of your past practice. Gemini can expand this into a detailed improvement plan.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildDashboardMetric(
                'Sessions',
                metrics.totalSessions.toString(),
                Icons.library_music,
              ),
              _buildDashboardMetric(
                'Minutes',
                metrics.totalMinutes.toString(),
                Icons.schedule,
              ),
              _buildDashboardMetric(
                'Avg Sur',
                '${metrics.averageAccuracy.toStringAsFixed(0)}%',
                Icons.tune,
              ),
              _buildDashboardMetric(
                'Streak',
                '${metrics.practiceStreak}d',
                Icons.local_fire_department,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInlineInsight('Weekly', '${metrics.weeklyMinutes} min'),
              _buildInlineInsight('Focus Raga', metrics.focusRaga),
              if (metrics.averageStability != null)
                _buildInlineInsight(
                  'Stability',
                  metrics.averageStability!.toStringAsFixed(1),
                ),
              if (metrics.averageBrightness != null)
                _buildInlineInsight(
                  'Brightness',
                  metrics.averageBrightness!.toStringAsFixed(0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _showProgressAnalysisDialog,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Detailed AI Analysis',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.deepPurpleAccent.withOpacity(0.16),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }

  Widget _buildQuickRecordCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurpleAccent.withOpacity(0.2),
            Colors.purpleAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: Colors.deepPurpleAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Record',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Record today\'s practice session',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showAddEntryDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Entry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMetric(String label, String value, IconData icon) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineInsight(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 6, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.84),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisChip(String trend) {
    Color color = Colors.blueAccent;
    final normalized = trend.toLowerCase();
    if (normalized.contains('improv')) {
      color = Colors.greenAccent;
    } else if (normalized.contains('attention') ||
        normalized.contains('focus')) {
      color = Colors.orangeAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Text(
        trend,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSnapshotCard(_PracticeSnapshot snapshot) {
    final isRecorded = snapshot.source == 'practice_session';
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: date + accuracy badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(snapshot.date),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snapshot.raga,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getAccuracyColor(
                          snapshot.pitchAccuracy,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getAccuracyColor(snapshot.pitchAccuracy),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${snapshot.pitchAccuracy}%',
                        style: TextStyle(
                          color: _getAccuracyColor(snapshot.pitchAccuracy),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // Edit/delete menu for manual journal entries
                    if (!isRecorded && snapshot.entryId != null) ...[  
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                        onSelected: (value) {
                          final entry = _journalEntries.firstWhere(
                            (e) => e.id == snapshot.entryId,
                            orElse: () => JournalEntry(
                              userId: '',
                              date: snapshot.date,
                              raga: snapshot.raga,
                              sur: '',
                              taal: '',
                              type: snapshot.type,
                              notes: snapshot.notes ?? '',
                              pitchAccuracy: snapshot.pitchAccuracy,
                              practiceTime: snapshot.practiceTime,
                            ),
                          );
                          if (value == 'edit') {
                            _showEditEntryDialog(context, entry);
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(context, entry);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Source + type tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag(
                  isRecorded ? '🎙 Recorded' : '📝 Manual',
                  isRecorded ? Icons.mic : Icons.edit_note,
                  isRecorded ? Colors.deepPurple : Colors.teal,
                ),
                _buildTag(snapshot.type, Icons.trending_up, Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            // Practice time row
            Row(
              children: [
                Icon(Icons.access_time, size: 15, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${snapshot.practiceTime} min',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                if (snapshot.bpm != null && snapshot.bpm! > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.speed, size: 15, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${snapshot.bpm!.toStringAsFixed(0)} BPM',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ],
            ),
            // Manual notes
            if (snapshot.notes != null && snapshot.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  snapshot.notes!,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            // Detailed audio stats
            if (snapshot.stability != null || snapshot.brightness != null) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _buildSnapshotStats(snapshot),
            ],
            // Missing swaras chips
            if (snapshot.missingNotesAI != null &&
                snapshot.missingNotesAI!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Missing swaras:',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: snapshot.missingNotesAI!
                    .map(
                      (note) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          note,
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            // Detected swaras chips
            if (snapshot.detectedNotes != null &&
                snapshot.detectedNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Detected:',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      snapshot.detectedNotes!.join(', '),
                      style: TextStyle(color: Colors.green[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            // AI Feedback section (collapsible)
            if (snapshot.aiFeedback != null &&
                snapshot.aiFeedback!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _AiFeedbackSection(feedback: snapshot.aiFeedback!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotStats(_PracticeSnapshot snapshot) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (snapshot.stability != null)
          _buildStatItem(
            'Stability',
            snapshot.stability!.toStringAsFixed(1),
            Icons.psychology,
          ),
        if (snapshot.brightness != null)
          _buildStatItem(
            'Brightness',
            snapshot.brightness!.toStringAsFixed(0),
            Icons.light_mode,
          ),
        _buildStatItem(
          'Missing',
          '${snapshot.missingNotesAI?.length ?? 0} swara${(snapshot.missingNotesAI?.length ?? 0) == 1 ? '' : 's'}',
          Icons.warning_amber,
        ),
        _buildStatItem(
          'Detected',
          '${snapshot.detectedNotes?.length ?? 0}',
          Icons.music_note,
        ),
      ],
    );
  }


  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    _showEntryDialog(context);
  }

  void _showEditEntryDialog(BuildContext context, JournalEntry entry) {
    _showEntryDialog(context, existingEntry: entry);
  }

  void _showEntryDialog(BuildContext context, {JournalEntry? existingEntry}) {
    final ragaController = TextEditingController(text: existingEntry?.raga);
    final surController = TextEditingController(text: existingEntry?.sur);
    final taalController = TextEditingController(text: existingEntry?.taal);
    final typeController = TextEditingController(text: existingEntry?.type);
    final notesController = TextEditingController(text: existingEntry?.notes);
    final practiceTimeController = TextEditingController(
      text: existingEntry?.practiceTime.toString() ?? '30',
    );
    final pitchAccuracyController = TextEditingController(
      text: existingEntry?.pitchAccuracy.toString() ?? '80',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            existingEntry == null ? 'Add Journal Entry' : 'Edit Journal Entry',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  ragaController,
                  'Raga',
                  'e.g., Raag Yaman',
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  surController,
                  'Sur',
                  'e.g., Shuddh Swars',
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  taalController,
                  'Taal',
                  'e.g., Teen Taal',
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  typeController,
                  'Type',
                  'e.g., Aaroh, Avroh',
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  notesController,
                  'Notes',
                  'How did it feel today?',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  practiceTimeController,
                  'Practice Time (minutes)',
                  '30',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  pitchAccuracyController,
                  'Pitch Accuracy (%)',
                  '80',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _saveEntry(
                  dialogContext,
                  existingEntry: existingEntry,
                  raga: ragaController.text,
                  sur: surController.text,
                  taal: taalController.text,
                  type: typeController.text,
                  notes: notesController.text,
                  practiceTime: int.tryParse(practiceTimeController.text) ?? 30,
                  pitchAccuracy:
                      int.tryParse(pitchAccuracyController.text) ?? 80,
                );
              },
              child: Text(existingEntry == null ? 'Add Entry' : 'Save Changes'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.deepPurpleAccent),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _saveEntry(
    BuildContext context, {
    JournalEntry? existingEntry,
    required String raga,
    required String sur,
    required String taal,
    required String type,
    required String notes,
    required int practiceTime,
    required int pitchAccuracy,
  }) async {
    if (raga.isEmpty || sur.isEmpty || taal.isEmpty || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (existingEntry != null) {
        final updatedEntry = existingEntry.copyWith(
          raga: raga,
          sur: sur,
          taal: taal,
          type: type,
          notes: notes,
          practiceTime: practiceTime,
          pitchAccuracy: pitchAccuracy,
        );
        await _updateJournalEntry(updatedEntry);
      } else {
        final newEntry = JournalEntry(
          userId: userId,
          date: DateTime.now(),
          raga: raga,
          sur: sur,
          taal: taal,
          type: type,
          notes: notes,
          practiceTime: practiceTime,
          pitchAccuracy: pitchAccuracy,
        );
        await _addJournalEntry(newEntry);
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      print('Error saving entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    JournalEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Entry?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete this journal entry for "${entry.raga}"? This action cannot be undone.',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && entry.id != null) {
      await _deleteJournalEntry(entry.id!);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}

class _PracticeSnapshot {
  final DateTime date;
  final String raga;
  final String type;
  final int practiceTime;
  final int pitchAccuracy;
  final double? stability;
  final double? brightness;
  final double? bpm;
  final List<String>? detectedNotes;
  final List<String>? missingNotesAI;
  final String? aiFeedback;
  final String? notes; // Manual journal notes
  final String? entryId; // ID of the source JournalEntry for edit/delete
  final String source;

  const _PracticeSnapshot({
    required this.date,
    required this.raga,
    required this.type,
    required this.practiceTime,
    required this.pitchAccuracy,
    required this.stability,
    required this.brightness,
    required this.bpm,
    required this.source,
    this.detectedNotes,
    this.missingNotesAI,
    this.aiFeedback,
    this.notes,
    this.entryId,
  });

  Map<String, dynamic> toAnalysisMap() {
    return {
      'date': date.toIso8601String(),
      'raga': raga,
      'type': type,
      'practice_time_minutes': practiceTime,
      'pitch_accuracy': pitchAccuracy,
      'stability': stability,
      'brightness': brightness,
      'bpm': bpm,
      'missing_swaras': missingNotesAI,
      'detected_swaras': detectedNotes,
      'source': source,
    };
  }
}

class _PracticeDashboardMetrics {
  final int totalSessions;
  final int totalMinutes;
  final double averageAccuracy;
  final int practiceStreak;
  final double? averageStability;
  final double? averageBrightness;
  final int weeklyMinutes;
  final String focusRaga;
  final String trendLabel;
  final Color trendColor;
  final double recentAverageAccuracy;

  const _PracticeDashboardMetrics({
    required this.totalSessions,
    required this.totalMinutes,
    required this.averageAccuracy,
    required this.practiceStreak,
    required this.averageStability,
    required this.averageBrightness,
    required this.weeklyMinutes,
    required this.focusRaga,
    required this.trendLabel,
    required this.trendColor,
    required this.recentAverageAccuracy,
  });
}

/// Collapsible widget to display AI feedback text in a journal card
class _AiFeedbackSection extends StatefulWidget {
  final String feedback;

  const _AiFeedbackSection({required this.feedback});

  @override
  State<_AiFeedbackSection> createState() => _AiFeedbackSectionState();
}

class _AiFeedbackSectionState extends State<_AiFeedbackSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.deepPurple[600],
              ),
              const SizedBox(width: 4),
              Text(
                'AI Guru Feedback',
                style: TextStyle(
                  color: Colors.deepPurple[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.deepPurple[400],
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.deepPurple.withOpacity(0.2),
              ),
            ),
            child: Text(
              widget.feedback,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

