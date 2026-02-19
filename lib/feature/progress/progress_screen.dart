import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/practice_session.dart';
import '../../services/app_state_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateService>(
      builder: (context, appState, child) {
        final user = appState.currentUser;
        final practiceSessions = appState.practiceSessions;
        final analytics = appState.userAnalytics;

        if (user == null) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.deepPurpleAccent,
              ),
            ),
          );
        }

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
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),

            // Practice streak
            _buildProgressCard(
              'Practice Streak',
              '${user.practiceStreak} days',
              Icons.local_fire_department,
              Colors.orange,
              'Keep it up! You\'re on fire!',
            ),

            const SizedBox(height: 16),

            // Total practice time
            _buildProgressCard(
              'Total Practice Time',
              '${(analytics['totalPracticeTime'] ?? 0) ~/ 60}h ${(analytics['totalPracticeTime'] ?? 0) % 60}m',
              Icons.access_time,
              Colors.blue,
              'Consistent practice leads to mastery',
            ),

            const SizedBox(height: 16),

            // Most practiced raga
            _buildProgressCard(
              'Most Practiced Raga',
              user.favoriteRaga.isNotEmpty ? user.favoriteRaga : 'No data yet',
              Icons.music_note,
              Colors.green,
              'Your favorite raga this month',
            ),

            const SizedBox(height: 16),

            // Average accuracy
            _buildProgressCard(
              'Average Pitch Accuracy',
              '${(analytics['averagePitchAccuracy'] ?? 0.0).toStringAsFixed(1)}%',
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
                  SizedBox(
                    height: 200,
                    child: _buildAccuracyImprovementChart(practiceSessions),
                  ),
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
                  SizedBox(
                    height: 200,
                    child: _buildTempoChart(practiceSessions),
                  ),
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
                          value:
                              (analytics['averagePitchAccuracy'] ?? 0.0) / 100,
                          color: Colors.deepPurpleAccent,
                          backgroundColor: Colors.grey,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(analytics['averagePitchAccuracy'] ?? 0.0).toStringAsFixed(1)}%',
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
                  ...practiceSessions
                      .take(10)
                      .map((session) => _buildPracticeSessionCard(session)),
                ],
              ),
            ),
          ],
        );
      },
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Tempo', '${session.tempo} BPM', Icons.speed),
              _buildStatItem(
                'Time',
                '${session.practiceTime}m',
                Icons.access_time,
              ),
              if (session.stability != null)
                _buildStatItem(
                  'Stability',
                  session.stability!.toStringAsFixed(1),
                  Icons.psychology,
                )
              else
                _buildStatItem(
                  'Missed',
                  '${session.missedNotes.length}',
                  Icons.error_outline,
                ),
            ],
          ),

          if (session.avgPitch != null || session.brightness != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (session.avgPitch != null)
                  _buildStatItem(
                    'Avg Pitch',
                    '${session.avgPitch!.toStringAsFixed(0)} Hz',
                    Icons.graphic_eq,
                  ),
                if (session.brightness != null)
                  _buildStatItem(
                    'Brightness',
                    session.brightness!.toStringAsFixed(0),
                    Icons.light_mode,
                  ),
                if (session.detectedNotes != null &&
                    session.detectedNotes!.isNotEmpty)
                  _buildStatItem(
                    'Notes',
                    '${session.detectedNotes!.length}',
                    Icons.music_note,
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Missed notes details (only if not showing stability in main row or if we have space)
          if (session.missedNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
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
          // const Spacer(),
          // Column(
          //   children: [
          //     Text(
          //       'Expected: ${note.expectedPitch}',
          //       style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          //     ),
          //     const SizedBox(width: 8),
          //     Text(
          //       'Actual: ${note.actualPitch}',
          //       style: TextStyle(fontSize: 11, color: Colors.red[600]),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _buildAccuracyImprovementChart(
    List<PracticeSession> practiceSessions,
  ) {
    final recentSessions = _recentSessions(practiceSessions);

    if (recentSessions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final dates = recentSessions.map((s) => _formatChartLabel(s.date)).toList();
    final accuracies = recentSessions
        .map((s) => s.pitchAccuracy.toDouble())
        .toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(recentSessions.length, (index) {
        final height = (accuracies[index] / 100) * 150;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 18,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dates[index],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${accuracies[index].toInt()}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTempoChart(List<PracticeSession> practiceSessions) {
    final recentSessions = _recentSessions(practiceSessions);

    if (recentSessions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final dates = recentSessions.map((s) => _formatChartLabel(s.date)).toList();
    final tempos = recentSessions.map((s) => s.tempo.toDouble()).toList();
    final maxTempo = tempos.reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(recentSessions.length, (index) {
        final height = (tempos[index] / maxTempo) * 150;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 18,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dates[index],
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${tempos[index].toInt()}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';

    return '${date.day}/${date.month}';
  }

  String _formatChartLabel(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Tdy';
    if (difference == 1) return 'Yst';
    if (difference < 7) return '${difference}d';

    return '${date.day}/${date.month}';
  }

  List<PracticeSession> _recentSessions(
    List<PracticeSession> practiceSessions, {
    int maxItems = 7,
  }) {
    final sortedSessions = List<PracticeSession>.from(practiceSessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedSessions.length <= maxItems) {
      return sortedSessions;
    }

    return sortedSessions.sublist(sortedSessions.length - maxItems);
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}
