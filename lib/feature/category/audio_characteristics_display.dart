import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/audio_characteristics.dart';
import '../../models/audio_feedback.dart';
import '../../services/indian_music_helper.dart';

class AudioCharacteristicsDisplay extends StatefulWidget {
  final AudioCharacteristics? referenceCharacteristics;
  final AudioCharacteristics? userCharacteristics;
  final AudioFeedback? feedback;
  final bool showComparison;

  const AudioCharacteristicsDisplay({
    super.key,
    this.referenceCharacteristics,
    this.userCharacteristics,
    this.feedback,
    this.showComparison = false,
  });

  @override
  State<AudioCharacteristicsDisplay> createState() =>
      _AudioCharacteristicsDisplayState();
}

class _AudioCharacteristicsDisplayState
    extends State<AudioCharacteristicsDisplay>
    with TickerProviderStateMixin {
  late AnimationController _chartController;
  late Animation<double> _chartAnimation;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _chartController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _chartAnimation = CurvedAnimation(
      parent: _chartController,
      curve: Curves.easeInOut,
    );
    _chartController.forward();
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurpleAccent.withOpacity(0.1),
            Colors.purpleAccent.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with tabs
          _buildHeader(),

          // Tab content
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.deepPurpleAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Audio Characteristics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tabs
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildTab('Overview', 0),
              _buildTab('Spectrum', 1),
              _buildTab('Comparison', 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
        _chartController.reset();
        _chartController.forward();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurpleAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent
                : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildSpectrumTab();
      case 2:
        return _buildComparisonTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    final characteristics =
        widget.userCharacteristics ?? widget.referenceCharacteristics;

    if (characteristics == null) {
      return const Center(
        child: Text(
          'No audio data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Main characteristics grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
            children: [
              _buildCharacteristicCard(
                'Pitch',
                '${characteristics.pitch.toStringAsFixed(1)} Hz',
                Icons.trending_up,
                Colors.blue,
                _getPitchDescription(characteristics.pitch),
              ),
              _buildCharacteristicCard(
                'Tempo',
                '${characteristics.tempo.toStringAsFixed(1)} BPM',
                Icons.speed,
                Colors.orange,
                _getTempoDescription(characteristics.tempo),
              ),
              _buildCharacteristicCard(
                'Volume',
                '${(characteristics.volume * 100).toStringAsFixed(1)}%',
                Icons.volume_up,
                Colors.green,
                _getVolumeDescription(characteristics.volume),
              ),
              _buildCharacteristicCard(
                'Duration',
                '${characteristics.duration.toStringAsFixed(1)}s',
                Icons.timer,
                Colors.purple,
                _getDurationDescription(characteristics.duration),
              ),
              _buildCharacteristicCard(
                'Quality',
                '${characteristics.qualityScore.toStringAsFixed(1)}%',
                Icons.star,
                _getQualityColor(characteristics.qualityScore),
                _getQualityDescription(characteristics.qualityScore),
              ),
              _buildCharacteristicCard(
                'Brightness',
                '${characteristics.spectralCentroid.toStringAsFixed(1)}',
                Icons.wb_sunny,
                Colors.amber,
                _getBrightnessDescription(characteristics.spectralCentroid),
              ),
            ],
          ),

          // Notes section
          if (characteristics.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesSection(characteristics.notes),
          ],
        ],
      ),
    );
  }

  Widget _buildSpectrumTab() {
    final characteristics =
        widget.userCharacteristics ?? widget.referenceCharacteristics;

    if (characteristics == null || characteristics.spectrum.isEmpty) {
      return const Center(
        child: Text(
          'No spectrum data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Spectrum chart
          SizedBox(
            height: 180,
            child: AnimatedBuilder(
              animation: _chartAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: SpectrumPainter(
                    characteristics.spectrum,
                    _chartAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Spectrum info
          _buildSpectrumInfo(characteristics),
        ],
      ),
    );
  }

  Widget _buildComparisonTab() {
    if (!widget.showComparison ||
        widget.referenceCharacteristics == null ||
        widget.userCharacteristics == null) {
      return const Center(
        child: Text(
          'No comparison data available',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Accuracy scores
          if (widget.feedback != null) ...[
            _buildAccuracyScores(),
            const SizedBox(height: 20),
          ],

          // Comparison charts
          _buildComparisonCharts(),
        ],
      ),
    );
  }

  Widget _buildCharacteristicCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(List<String> notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.music_note, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Detected Notes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: notes
                .map((note) => _buildNoteChip(_formatNote(note)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteChip(String note) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.5)),
      ),
      child: Text(
        note,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSpectrumInfo(AudioCharacteristics characteristics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Dominant Freq',
                  '${characteristics.dominantFrequency.toStringAsFixed(1)} Hz',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Frequency Range',
                  '${characteristics.frequencyRange['min']!.toStringAsFixed(1)} - ${characteristics.frequencyRange['max']!.toStringAsFixed(1)} Hz',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Spectral Centroid',
                  '${characteristics.spectralCentroid.toStringAsFixed(1)}',
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  'Zero Crossing Rate',
                  '${characteristics.zeroCrossingRate.toStringAsFixed(3)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyScores() {
    final feedback = widget.feedback!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Accuracy Scores',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildAccuracyItem(
                  'Pitch',
                  '${feedback.pitchAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(feedback.pitchAccuracy),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAccuracyItem(
                  'Tempo',
                  '${feedback.tempoAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(feedback.tempoAccuracy),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAccuracyItem(
                  'Rhythm',
                  '${feedback.rhythmAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(feedback.rhythmAccuracy),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildComparisonCharts() {
    return Column(
      children: [
        _buildComparisonChart(
          'Pitch Comparison',
          widget.referenceCharacteristics!.pitch,
          widget.userCharacteristics!.pitch,
          'Hz',
        ),
        const SizedBox(height: 16),
        _buildComparisonChart(
          'Tempo Comparison',
          widget.referenceCharacteristics!.tempo,
          widget.userCharacteristics!.tempo,
          'BPM',
        ),
      ],
    );
  }

  Widget _buildComparisonChart(
    String title,
    double reference,
    double user,
    String unit,
  ) {
    final maxValue = math.max(reference, user) * 1.2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  child: _buildBarChart(
                    'Reference',
                    reference,
                    maxValue,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBarChart(
                    'Your Audio',
                    user,
                    maxValue,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(
    String label,
    double value,
    double maxValue,
    Color color,
  ) {
    final height = (value / maxValue).clamp(0.0, 1.0);

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _chartAnimation,
            builder: (context, child) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final barHeight =
                      constraints.maxHeight * height * _chartAnimation.value;
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${value.toStringAsFixed(1)} $label',
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper methods for descriptions
  String _getPitchDescription(double pitch) {
    if (pitch < 100) return 'Very low';
    if (pitch < 200) return 'Low';
    if (pitch < 400) return 'Medium';
    if (pitch < 800) return 'High';
    return 'Very high';
  }

  String _getTempoDescription(double tempo) {
    if (tempo < 60) return 'Very slow';
    if (tempo < 80) return 'Slow';
    if (tempo < 120) return 'Moderate';
    if (tempo < 160) return 'Fast';
    return 'Very fast';
  }

  String _getVolumeDescription(double volume) {
    if (volume < 0.1) return 'Very quiet';
    if (volume < 0.3) return 'Quiet';
    if (volume < 0.7) return 'Moderate';
    if (volume < 0.9) return 'Loud';
    return 'Very loud';
  }

  String _getDurationDescription(double duration) {
    if (duration < 1) return 'Very short';
    if (duration < 5) return 'Short';
    if (duration < 15) return 'Medium';
    if (duration < 30) return 'Long';
    return 'Very long';
  }

  String _getQualityDescription(double quality) {
    if (quality >= 80) return 'Excellent';
    if (quality >= 60) return 'Good';
    if (quality >= 40) return 'Fair';
    return 'Poor';
  }

  String _getBrightnessDescription(double brightness) {
    if (brightness < 1000) return 'Dark';
    if (brightness < 2000) return 'Medium';
    if (brightness < 3000) return 'Bright';
    return 'Very bright';
  }

  Color _getQualityColor(double quality) {
    if (quality >= 80) return Colors.green;
    if (quality >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }

  String _formatNote(String note) {
    final sargam = IndianMusicHelper.westernToSargamNote(note);
    return sargam;
  }
}

class SpectrumPainter extends CustomPainter {
  final List<double> spectrum;
  final double animationValue;

  SpectrumPainter(this.spectrum, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final paint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.deepPurpleAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final width = size.width;
    final height = size.height;
    final maxValue = spectrum.reduce(math.max);

    for (int i = 0; i < spectrum.length; i++) {
      final x = (i / spectrum.length) * width;
      final normalizedValue = spectrum[i] / maxValue;
      final y = height - (normalizedValue * height * animationValue);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(width, height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpectrumPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum ||
        oldDelegate.animationValue != animationValue;
  }
}
