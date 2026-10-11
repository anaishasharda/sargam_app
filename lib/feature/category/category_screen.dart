import 'package:flutter/material.dart';
import 'package:sargam_app/feature/category/level_detail.dart';
import 'package:sargam_app/models/raag_entry.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static final List<RagaData> _ragaDatabase = [
    // Beginner Ragas — Bilawal first (suddh major scale, easiest entry point).
    RagaData(
      name: 'Raag Bilawal',
      level: 'Beginner',
      description:
          'The shuddh (natural) scale — the simplest starting point with all suddh notes',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
      aarohAudioPath: 'assets/audio/raag_bilawal_aaroh.mp4',
      avrohAudioPath: 'assets/audio/raag_bilawal_avroh.mp4',
      swarmalikaAudioPath: 'assets/audio/bilawal_swarmalika.mp3',
    ),
    RagaData(
      name: 'Raag Bhoopali',
      level: 'Intermediate',
      description: 'A pentatonic raga with a joyful and uplifting character',
      notes: ['Sa', 'Re', 'Ga', 'Pa', 'Dha'],
      aarohAudioPath: 'assets/audio/raag_bhoopali_aaroh.wav',
      avrohAudioPath: 'assets/audio/raag_bhoopali_avroh.wav',
      swarmalikaAudioPath: 'assets/audio/bhoopali_swarmalika.mp3',
    ),
    // Intermediate Ragas
    RagaData(
      name: 'Raag Bhairav',
      level: 'Intermediate',
      description: 'A morning raga with a serious and devotional mood',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
      aarohAudioPath: 'assets/audio/raag_bhairav_aaroh.wav',
      avrohAudioPath: 'assets/audio/raag_bhairav_avroh.wav',
      swarmalikaAudioPath: 'assets/audio/bhairav_swarmalika.mp3',
    ),
    // RagaData(
    //   name: 'Raag Des',
    //   level: 'Intermediate',
    //   description: 'A romantic raga with a sweet and melodious character',
    //   notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
    //   aarohAudioPath: 'assets/audio/des_aaroh.mp3',
    //   avrohAudioPath: 'assets/audio/des_avroh.mp3',
    //   swarmalikaAudioPath: 'assets/audio/des_swarmalika.mp3',
    // ),
    // Advanced Ragas
    RagaData(
      name: 'Raag Bhairavi',
      level: 'Advanced',
      description: 'A morning raga with deep emotional expression',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
      aarohAudioPath: 'assets/audio/bhairavi_aaroh.mp3',
      avrohAudioPath: 'assets/audio/bhairavi_avroh.mp3',
      swarmalikaAudioPath: 'assets/audio/bhairavi_swarmalika.mp3',
    ),
    // RagaData(
    //   name: 'Raag Durga',
    //   level: 'Advanced',
    //   description: 'A pentatonic raga with a powerful and majestic mood',
    //   notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha'],
    //   aarohAudioPath: 'assets/audio/durga_aaroh.mp3',
    //   avrohAudioPath: 'assets/audio/durga_avroh.mp3',
    //   swarmalikaAudioPath: 'assets/audio/durga_swarmalika.mp3',
    // ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: CustomScrollView(
          slivers: [
            // Welcome Header
            SliverToBoxAdapter(child: _buildWelcomeHeader()),

            // Quick Stats
            SliverToBoxAdapter(child: _buildQuickStats()),

            // Categories
            SliverToBoxAdapter(child: _buildCategoriesSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurpleAccent.withValues(alpha: 0.3),
            Colors.purpleAccent.withValues(alpha: 0.2),
            Colors.blueAccent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to Riti',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Master the art of Indian classical music',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Start your musical journey today',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('3', 'Ragas', Icons.music_note, Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '3',
              'Levels',
              Icons.trending_up,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Multiple',
              'Practice',
              Icons.play_circle,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose Your Level',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a difficulty level to start practicing',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          _buildCategoryTile(
            context,
            'Beginner',
            'Perfect for newcomers to Indian classical music',
            _ragaDatabase.where((r) => r.level == 'Beginner').toList(),
            Colors.green,
            Icons.school,
            'Start Here',
          ),
          const SizedBox(height: 16),
          _buildCategoryTile(
            context,
            'Intermediate',
            'For those with some experience in classical music',
            _ragaDatabase.where((r) => r.level == 'Intermediate').toList(),
            Colors.blue,
            Icons.trending_up,
            'Level Up',
          ),
          const SizedBox(height: 16),
          _buildCategoryTile(
            context,
            'Advanced',
            'Master-level ragas for experienced practitioners',
            _ragaDatabase.where((r) => r.level == 'Advanced').toList(),
            Colors.purple,
            Icons.star,
            'Master',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    String title,
    String subtitle,
    List<RagaData> ragas,
    Color color,
    IconData icon,
    String badge,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LevelDetailScreen(level: title, ragas: ragas),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${ragas.length} ragas available',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[600],
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
