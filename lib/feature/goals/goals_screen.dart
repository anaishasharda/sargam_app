import 'package:flutter/material.dart';

import '../../models/practice_goal.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<PracticeGoal> _practiceGoals = [];

  @override
  void initState() {
    super.initState();
    _initializeSampleGoals();
  }

  void _initializeSampleGoals() {
    _practiceGoals.addAll([
      PracticeGoal(
        title: 'Practice Yaman for 7 days',
        description: 'Daily practice of Raag Yaman to improve consistency',
        targetDays: 7,
        completedDays: 3,
        raga: 'Raag Yaman',
        deadline: DateTime.now().add(const Duration(days: 4)),
      ),
      PracticeGoal(
        title: 'Improve pitch control this week',
        description: 'Focus on hitting the right notes consistently',
        targetDays: 7,
        completedDays: 5,
        raga: 'General',
        deadline: DateTime.now().add(const Duration(days: 2)),
      ),
      PracticeGoal(
        title: 'Master Raag Bhairav',
        description: 'Complete all practice modes for Raag Bhairav',
        targetDays: 14,
        completedDays: 8,
        raga: 'Raag Bhairav',
        deadline: DateTime.now().add(const Duration(days: 6)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Practice Goals',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set and track your musical milestones',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),

              // Add new goal button
              Container(
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
                    Icon(Icons.flag, color: Colors.deepPurpleAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Set New Goal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Create a new practice challenge',
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
                      onPressed: () => _showAddGoalDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Goal'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Goals list
        Expanded(
          child: _practiceGoals.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        size: 64,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No practice goals yet',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Set goals to track your progress!',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _practiceGoals.length,
                  itemBuilder: (context, index) {
                    final goal = _practiceGoals[index];
                    return _buildGoalCard(goal);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(PracticeGoal goal) {
    final progress = goal.completedDays / goal.targetDays;
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: daysLeft <= 0 ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    daysLeft <= 0 ? 'Overdue' : '$daysLeft days left',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              goal.description,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),

            const SizedBox(height: 16),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${goal.completedDays}/${goal.targetDays} days',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? Colors.green : Colors.deepPurpleAccent,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurpleAccent,
                      side: const BorderSide(color: Colors.deepPurpleAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _updateGoalProgress(goal),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Mark Complete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _editGoal(goal),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context) {
    // TODO: Implement add goal dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add goal feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _updateGoalProgress(PracticeGoal goal) {
    setState(() {
      if (goal.completedDays < goal.targetDays) {
        goal.completedDays++;
      }
    });
  }

  void _editGoal(PracticeGoal goal) {
    // TODO: Implement goal editing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Goal editing coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
