import 'package:flutter/material.dart';

import '../../models/journal_entry.dart';
import '../../models/practice_session.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final List<JournalEntry> _journalEntries = [];
  final List<PracticeSession> _practiceSessions = [];

  @override
  void initState() {
    super.initState();
    _initializeSampleData();
  }

  void _initializeSampleData() {
    _journalEntries.addAll([
      JournalEntry(
        date: DateTime.now().subtract(const Duration(days: 1)),
        raga: 'Raag Yaman',
        sur: 'Shuddh Swars',
        taal: 'Teen Taal',
        type: 'Aaroh',
        notes: 'Felt good, nailed the aalap! Voice was clear today.',
        pitchAccuracy: 85,
        practiceTime: 45,
      ),
      JournalEntry(
        date: DateTime.now().subtract(const Duration(days: 2)),
        raga: 'Raag Bhairav',
        sur: 'Komal Swars',
        taal: 'Ek Taal',
        type: 'Avroh',
        notes: 'My voice is tired today. Need to work on pitch control.',
        pitchAccuracy: 72,
        practiceTime: 30,
      ),
      JournalEntry(
        date: DateTime.now().subtract(const Duration(days: 3)),
        raga: 'Raag Bhoopali',
        sur: 'Shuddh Swars',
        taal: 'Dadra',
        type: 'Swarmalika',
        notes: 'Great practice session! Improved a lot on Sa Re Ga.',
        pitchAccuracy: 88,
        practiceTime: 60,
      ),
    ]);

    _practiceSessions.addAll([
      PracticeSession(
        date: DateTime.now().subtract(const Duration(days: 1)),
        raga: 'Raag Yaman',
        type: 'Aaroh',
        missedNotes: [
          MissedNote(
            note: 'Sa',
            count: 3,
            expectedPitch: 'C4',
            actualPitch: 'C#4',
          ),
          MissedNote(
            note: 'Re',
            count: 2,
            expectedPitch: 'D4',
            actualPitch: 'D#4',
          ),
        ],
        tempo: 80,
        pitchAccuracy: 85,
        practiceTime: 45,
      ),
      PracticeSession(
        date: DateTime.now().subtract(const Duration(days: 2)),
        raga: 'Raag Bhairav',
        type: 'Avroh',
        missedNotes: [
          MissedNote(
            note: 'Ga',
            count: 5,
            expectedPitch: 'E4',
            actualPitch: 'F4',
          ),
          MissedNote(
            note: 'Ma',
            count: 3,
            expectedPitch: 'F4',
            actualPitch: 'F#4',
          ),
          MissedNote(
            note: 'Pa',
            count: 2,
            expectedPitch: 'G4',
            actualPitch: 'G#4',
          ),
        ],
        tempo: 75,
        pitchAccuracy: 72,
        practiceTime: 30,
      ),
      PracticeSession(
        date: DateTime.now().subtract(const Duration(days: 3)),
        raga: 'Raag Bhoopali',
        type: 'Swarmalika',
        missedNotes: [
          MissedNote(
            note: 'Sa',
            count: 1,
            expectedPitch: 'C4',
            actualPitch: 'C#4',
          ),
          MissedNote(
            note: 'Ni',
            count: 2,
            expectedPitch: 'B4',
            actualPitch: 'C5',
          ),
        ],
        tempo: 85,
        pitchAccuracy: 88,
        practiceTime: 60,
      ),
      PracticeSession(
        date: DateTime.now().subtract(const Duration(days: 4)),
        raga: 'Raag Yaman',
        type: 'Aaroh',
        missedNotes: [
          MissedNote(
            note: 'Sa',
            count: 4,
            expectedPitch: 'C4',
            actualPitch: 'C#4',
          ),
          MissedNote(
            note: 'Re',
            count: 3,
            expectedPitch: 'D4',
            actualPitch: 'D#4',
          ),
          MissedNote(
            note: 'Ga',
            count: 2,
            expectedPitch: 'E4',
            actualPitch: 'F4',
          ),
        ],
        tempo: 70,
        pitchAccuracy: 78,
        practiceTime: 40,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        const Text(
          'Your Progress',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your musical journey',
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
        ),
        const SizedBox(height: 32),

        // Practice streak
        _buildProgressCard(
          'Practice Streak',
          '7 days',
          Icons.local_fire_department,
          Colors.orange,
          'Keep it up! You\'re on fire!',
        ),

        const SizedBox(height: 16),

        // Total practice time
        _buildProgressCard(
          'Total Practice Time',
          '${_calculateTotalPracticeTime()} hours',
          Icons.access_time,
          Colors.blue,
          'Consistent practice leads to mastery',
        ),

        const SizedBox(height: 16),

        // Most practiced raga
        _buildProgressCard(
          'Most Practiced Raga',
          'Raag Yaman',
          Icons.music_note,
          Colors.green,
          'Your favorite raga this month',
        ),

        const SizedBox(height: 16),

        // Average accuracy
        _buildProgressCard(
          'Average Pitch Accuracy',
          '${_calculateAverageAccuracy()}%',
          Icons.trending_up,
          Colors.purple,
          'Great progress on pitch control!',
        ),

        const SizedBox(height: 32),

        // Weekly practice chart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Practice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: _buildWeeklyChart()),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Pitch accuracy improvement chart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pitch Accuracy Improvement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: _buildAccuracyImprovementChart()),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Tempo tracking chart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tempo Progress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: _buildTempoChart()),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Pitch accuracy details
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overall Pitch Accuracy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Current Average',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _calculateAverageAccuracy() / 100,
                      color: Colors.deepPurpleAccent,
                      backgroundColor: Colors.grey,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_calculateAverageAccuracy()}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Practice session details
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Practice Session Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._practiceSessions.map(
                (session) => _buildPracticeSessionCard(session),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeSessionCard(PracticeSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.raga} - ${session.type}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatDate(session.date),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getAccuracyColor(
                    session.pitchAccuracy,
                  ).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getAccuracyColor(session.pitchAccuracy),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${session.pitchAccuracy}%',
                  style: TextStyle(
                    color: _getAccuracyColor(session.pitchAccuracy),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _buildStatItem('Tempo', '${session.tempo} BPM', Icons.speed),
              const SizedBox(width: 20),
              _buildStatItem(
                'Time',
                '${session.practiceTime}m',
                Icons.access_time,
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                'Missed',
                '${session.missedNotes.length}',
                Icons.error_outline,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Missed notes details
          if (session.missedNotes.isNotEmpty) ...[
            const Text(
              'Missed Notes:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...session.missedNotes.map((note) => _buildMissedNoteRow(note)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildMissedNoteRow(MissedNote note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.music_note, size: 16, color: Colors.red[600]),
          const SizedBox(width: 8),
          Text(
            '${note.note}: ${note.count} times',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.red[700],
            ),
          ),
          const Spacer(),
          Text(
            'Expected: ${note.expectedPitch}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(width: 8),
          Text(
            'Actual: ${note.actualPitch}',
            style: TextStyle(fontSize: 11, color: Colors.red[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyImprovementChart() {
    // Sort sessions by date for chronological order
    final sortedSessions = List<PracticeSession>.from(_practiceSessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedSessions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final dates = sortedSessions.map((s) => _formatDate(s.date)).toList();
    final accuracies = sortedSessions
        .map((s) => s.pitchAccuracy.toDouble())
        .toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(sortedSessions.length, (index) {
        final height = (accuracies[index] / 100) * 150;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dates[index],
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
            Text(
              '${accuracies[index].toInt()}%',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTempoChart() {
    // Sort sessions by date for chronological order
    final sortedSessions = List<PracticeSession>.from(_practiceSessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedSessions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final dates = sortedSessions.map((s) => _formatDate(s.date)).toList();
    final tempos = sortedSessions.map((s) => s.tempo.toDouble()).toList();
    final maxTempo = tempos.reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(sortedSessions.length, (index) {
        final height = (tempos[index] / maxTempo) * 150;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dates[index],
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
            Text(
              '${tempos[index].toInt()}',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProgressCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    // Simple bar chart for weekly practice
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final practiceMinutes = [45, 30, 60, 45, 75, 90, 60];
    final maxMinutes = practiceMinutes.reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final height = (practiceMinutes[index] / maxMinutes) * 150;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 30,
              height: height,
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              weekDays[index],
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${practiceMinutes[index]}m',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        );
      }),
    );
  }

  int _calculateTotalPracticeTime() {
    return _journalEntries.fold(0, (sum, entry) => sum + entry.practiceTime) ~/
        60;
  }

  int _calculateAverageAccuracy() {
    if (_journalEntries.isEmpty) return 0;
    final total = _journalEntries.fold(
      0,
      (sum, entry) => sum + entry.pitchAccuracy,
    );
    return total ~/ _journalEntries.length;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    return '${date.day}/${date.month}';
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}
