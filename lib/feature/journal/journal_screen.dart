import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/journal_entry.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<JournalEntry> _journalEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJournalEntries();
  }

  // Firebase CRUD Operations
  Future<void> _loadJournalEntries() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final querySnapshot = await _firestore
            .collection('journal_entries')
            .where('userId', isEqualTo: userId)
            .orderBy('date', descending: true)
            .get();

        setState(() {
          _journalEntries = querySnapshot.docs
              .map((doc) => JournalEntry.fromFirestore(doc.data(), doc.id))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading journal entries: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addJournalEntry(JournalEntry entry) async {
    try {
      await _firestore.collection('journal_entries').add(entry.toFirestore());
      _loadJournalEntries();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding journal entry: $e');
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
      _loadJournalEntries();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating journal entry: $e');
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
      _loadJournalEntries();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal entry deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting journal entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting entry: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

              // Quick record button
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
              ),
            ],
          ),
        ),

        // Journal entries
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _journalEntries.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 64,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No journal entries yet',
                        style: TextStyle(color: Colors.white54, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Start recording your practice sessions!',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _journalEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _journalEntries[index];
                    return _buildJournalEntryCard(entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJournalEntryCard(JournalEntry entry) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and accuracy
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(entry.date),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.raga,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getAccuracyColor(
                          entry.pitchAccuracy,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getAccuracyColor(entry.pitchAccuracy),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${entry.pitchAccuracy}%',
                        style: TextStyle(
                          color: _getAccuracyColor(entry.pitchAccuracy),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                      onSelected: (value) {
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
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTag(entry.sur, Icons.music_note, Colors.green),
                _buildTag(entry.taal, Icons.timer, Colors.blue),
                _buildTag(entry.type, Icons.trending_up, Colors.orange),
              ],
            ),

            const SizedBox(height: 16),

            // Notes
            if (entry.notes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  entry.notes,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Practice time
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${entry.practiceTime} minutes',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ],
        ),
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
        // Update existing entry
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
        // Create new entry
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
