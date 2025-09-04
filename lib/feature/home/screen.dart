import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

void main() => runApp(const HomeScreen());

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const CategoriesScreen(),
    const GoalsScreen(),
    const JournalScreen(),
    const ProgressScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10002B), Color(0xFF240046), Color(0xFF3C096C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(child: _screens[_selectedIndex]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.deepPurpleAccent,
        unselectedItemColor: Colors.white60,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Goals'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Journal'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------- CATEGORIES SCREEN ----------------

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
    // Beginner Ragas
    RagaData(
      name: 'Raag Yaman',
      level: 'Beginner',
      description: 'A beautiful evening raga with a peaceful and romantic mood',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
      aarohAudioPath: 'assets/audio/yaman_aaroh.mp3',
      avrohAudioPath: 'assets/audio/yaman_avroh.mp3',
      swarmalikaAudioPath: 'assets/audio/yaman_swarmalika.mp3',
    ),
    RagaData(
      name: 'Raag Bhoopali',
      level: 'Beginner',
      description: 'A pentatonic raga with a joyful and uplifting character',
      notes: ['Sa', 'Re', 'Ga', 'Pa', 'Dha'],
      aarohAudioPath: 'assets/audio/bhoopali_aaroh.mp3',
      avrohAudioPath: 'assets/audio/bhoopali_avroh.mp3',
      swarmalikaAudioPath: 'assets/audio/bhoopali_swarmalika.mp3',
    ),
    // Intermediate Ragas
    RagaData(
      name: 'Raag Bhairav',
      level: 'Intermediate',
      description: 'A morning raga with a serious and devotional mood',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
      aarohAudioPath: 'assets/audio/bhairav_aaroh.mp3',
      avrohAudioPath: 'assets/audio/bhairav_avroh.mp3',
      swarmalikaAudioPath: 'assets/audio/bhairav_swarmalika.mp3',
    ),
    RagaData(
      name: 'Raag Des',
      level: 'Intermediate',
      description: 'A romantic raga with a sweet and melodious character',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha', 'Ni'],
      aarohAudioPath: 'assets/audio/des_aaroh.mp3',
      avrohAudioPath: 'assets/audio/des_avroh.mp3',
      swarmalikaAudioPath: 'assets/audio/des_swarmalika.mp3',
    ),
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
    RagaData(
      name: 'Raag Durga',
      level: 'Advanced',
      description: 'A pentatonic raga with a powerful and majestic mood',
      notes: ['Sa', 'Re', 'Ga', 'Ma', 'Pa', 'Dha'],
      aarohAudioPath: 'assets/audio/durga_aaroh.mp3',
      avrohAudioPath: 'assets/audio/durga_avroh.mp3',
      swarmalikaAudioPath: 'assets/audio/durga_swarmalika.mp3',
    ),
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
            Colors.deepPurpleAccent.withOpacity(0.3),
            Colors.purpleAccent.withOpacity(0.2),
            Colors.blueAccent.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
                      'Welcome to Sargam',
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
                        color: Colors.white.withOpacity(0.8),
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
              color: Colors.white.withOpacity(0.15),
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
                    color: Colors.white.withOpacity(0.9),
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
            child: _buildStatCard('6', 'Ragas', Icons.music_note, Colors.green),
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
              '18',
              'Practice Modes',
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
            color: Colors.black.withOpacity(0.1),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
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
              color: Colors.white.withOpacity(0.7),
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
            color: Colors.black.withOpacity(0.1),
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
                      colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
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
                              color: color.withOpacity(0.1),
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

// ---------------- LEVEL DETAIL SCREEN ----------------

class LevelDetailScreen extends StatelessWidget {
  final String level;
  final List<RagaData> ragas;

  const LevelDetailScreen({
    super.key,
    required this.level,
    required this.ragas,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF240046),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$level Ragas',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${ragas.length} ragas available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: ragas.length,
        itemBuilder: (context, index) {
          final raga = ragas[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                      builder: (_) => RagaPracticeOptionsScreen(ragaData: raga),
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
                            colors: [
                              Colors.deepPurpleAccent.withOpacity(0.8),
                              Colors.purpleAccent.withOpacity(0.6),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              raga.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              raga.description,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Notes: ${raga.notes.join(' ')}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
        },
      ),
    );
  }
}

// ---------------- RAGA PRACTICE OPTIONS SCREEN ----------------

class RagaPracticeOptionsScreen extends StatelessWidget {
  final RagaData ragaData;

  const RagaPracticeOptionsScreen({super.key, required this.ragaData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF240046),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Practice ${ragaData.name}'),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 48,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ragaData.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ragaData.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notes: ${ragaData.notes.join(' ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Practice options
            Expanded(
              child: ListView(
                children: [
                  _practiceOptionTile(
                    context,
                    'Practice Aaroh',
                    'Ascending scale practice with audio feedback',
                    Icons.trending_up,
                    Colors.green,
                    'Aaroh',
                    ragaData.aarohAudioPath,
                  ),
                  const SizedBox(height: 16),
                  _practiceOptionTile(
                    context,
                    'Practice Avroh',
                    'Descending scale practice with audio feedback',
                    Icons.trending_down,
                    Colors.blue,
                    'Avroh',
                    ragaData.avrohAudioPath,
                  ),
                  const SizedBox(height: 16),
                  _practiceOptionTile(
                    context,
                    'Practice Swarmalika',
                    'Melody practice with lyrics and feedback',
                    Icons.lyrics,
                    Colors.orange,
                    'Swarmalika',
                    ragaData.swarmalikaAudioPath,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _practiceOptionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String practiceType,
    String audioPath,
  ) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PracticeScreen(
                ragaData: ragaData,
                practiceType: practiceType,
                audioPath: audioPath,
              ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- PRACTICE SCREEN ----------------

class PracticeScreen extends StatefulWidget {
  final RagaData ragaData;
  final String practiceType;
  final String audioPath;

  const PracticeScreen({
    super.key,
    required this.ragaData,
    required this.practiceType,
    required this.audioPath,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  bool _isAnalyzing = false;
  AudioFeedback? _lastFeedback;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await _audioService.requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF240046),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.practiceType} - ${widget.ragaData.name}'),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Practice info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurpleAccent.withOpacity(0.2),
                    Colors.purpleAccent.withOpacity(0.1),
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
                  Icon(
                    _getPracticeIcon(),
                    size: 48,
                    color: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.practiceType} Practice',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ragaData.name,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${widget.ragaData.notes.join(' ')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Audio feedback section
            if (_lastFeedback != null) _buildFeedbackCard(),

            const SizedBox(height: 24),

            // Control buttons
            Expanded(
              child: Column(
                children: [
                  // Audio controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _controlButton(
                        'Play Reference',
                        Icons.play_arrow,
                        Colors.green,
                        _audioService.isPlaying,
                        () => _toggleAudio(),
                      ),
                      _controlButton(
                        'Stop',
                        Icons.stop,
                        Colors.red,
                        false,
                        () => _stopAudio(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Practice controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _controlButton(
                        'Record Practice',
                        Icons.fiber_manual_record,
                        Colors.orange,
                        _audioService.isRecording,
                        () => _toggleRecording(),
                      ),
                      _controlButton(
                        'Analyze Audio',
                        Icons.analytics,
                        Colors.purple,
                        _isAnalyzing,
                        () => _analyzeAudio(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Status indicator
                  if (_audioService.isRecording)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.withOpacity(0.3),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.orange,
                              size: 32,
                            ),
                          ),
                        );
                      },
                    ),

                  if (_isAnalyzing)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.purple.withOpacity(0.3),
                        border: Border.all(color: Colors.purple, width: 2),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.purple,
                        size: 32,
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Practice log button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                      onPressed: () => _logPractice(),
                      icon: const Icon(Icons.book),
                      label: const Text(
                        'Log Practice Session',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPracticeIcon() {
    switch (widget.practiceType) {
      case 'Aaroh':
        return Icons.trending_up;
      case 'Avroh':
        return Icons.trending_down;
      case 'Swarmalika':
        return Icons.lyrics;
      default:
        return Icons.music_note;
    }
  }

  Widget _controlButton(
    String label,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: isActive ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: isActive ? Colors.white : color, size: 32),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackCard() {
    if (_lastFeedback == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.deepPurpleAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Audio Analysis Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Accuracy scores
          Row(
            children: [
              Expanded(
                child: _buildAccuracyItem(
                  'Pitch Accuracy',
                  '${_lastFeedback!.pitchAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(_lastFeedback!.pitchAccuracy.toInt()),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAccuracyItem(
                  'Tempo Accuracy',
                  '${_lastFeedback!.tempoAccuracy.toStringAsFixed(1)}%',
                  _getAccuracyColor(_lastFeedback!.tempoAccuracy.toInt()),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Overall feedback
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _lastFeedback!.overallFeedback,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          if (_lastFeedback!.missedNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Missed Notes:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _lastFeedback!.missedNotes
                  .map(
                    (note) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        note,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],

          if (_lastFeedback!.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Suggestions:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._lastFeedback!.suggestions.map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _toggleAudio() async {
    if (_audioService.isPlaying) {
      await _audioService.stopAudio();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio stopped'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    } else {
      // Extract just the filename from the full path
      final audioFileName = widget.audioPath.split('/').last;
      await _audioService.playAudio(
        audioFileName,
        ragaName: widget.ragaData.name,
        practiceType: widget.practiceType,
      );
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Playing ${widget.practiceType} for ${widget.ragaData.name}\n(Using TTS - Add audio files to assets/audio/ for real playback)',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  void _stopAudio() async {
    await _audioService.stopAudio();
    setState(() {});
  }

  void _toggleRecording() async {
    if (_audioService.isRecording) {
      final recordingPath = await _audioService.stopRecording();
      _pulseController.stop();
      setState(() {});

      if (recordingPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording saved: ${recordingPath.split('/').last}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      await _audioService.startRecording();
      _pulseController.repeat(reverse: true);
      setState(() {});
    }
  }

  void _analyzeAudio() {
    setState(() {
      _isAnalyzing = true;
    });

    // Simulate audio analysis
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isAnalyzing = false;
        _lastFeedback = _generateSampleFeedback();
      });
    });

    // TODO: Implement actual audio comparison logic
  }

  AudioFeedback _generateSampleFeedback() {
    // Generate sample feedback based on practice type
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    return AudioFeedback(
      pitchAccuracy: 75.0 + (random % 20),
      tempoAccuracy: 80.0 + (random % 15),
      missedNotes: ['Sa', 'Re', 'Ga'].take(random % 3).toList(),
      suggestions: [
        'Try to hold each note for a longer duration',
        'Focus on the transition between Sa and Re',
        'Practice with a slower tempo first',
      ],
      overallFeedback:
          'Good effort! Your pitch accuracy is improving. Focus on the missed notes and try to maintain consistent tempo.',
    );
  }

  void _logPractice() {
    // TODO: Implement practice logging logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Practice session logged for ${widget.ragaData.name}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.blue;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}

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

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with TickerProviderStateMixin {
  final List<JournalEntry> _journalEntries = [];
  bool _isRecording = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Initialize with sample data
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
                      onPressed: () => _showQuickRecordDialog(context),
                      icon: const Icon(Icons.fiber_manual_record, size: 16),
                      label: const Text('Record'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Journal entries
        Expanded(
          child: _journalEntries.isEmpty
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
                Column(
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

  void _showQuickRecordDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildQuickRecordDialog(),
    );
  }

  Widget _buildQuickRecordDialog() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF240046),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Record Practice Session',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Recording controls
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRecording ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording
                                ? Colors.red.withOpacity(0.3)
                                : Colors.deepPurpleAccent.withOpacity(0.3),
                            border: Border.all(
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.deepPurpleAccent,
                              width: 3,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              size: 40,
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.deepPurpleAccent,
                            ),
                            onPressed: () {
                              setState(() {
                                _isRecording = !_isRecording;
                              });
                              if (_isRecording) {
                                _pulseController.repeat(reverse: true);
                              } else {
                                _pulseController.stop();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? 'Recording...' : 'Tap to start recording',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Quick entry form
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildQuickInputField('Raga', 'e.g., Raag Yaman'),
                    const SizedBox(height: 16),
                    _buildQuickInputField('Sur', 'e.g., Shuddh Swars'),
                    const SizedBox(height: 16),
                    _buildQuickInputField('Taal', 'e.g., Teen Taal'),
                    const SizedBox(height: 16),
                    _buildQuickInputField('Type', 'e.g., Aaroh, Avroh'),
                    const SizedBox(height: 16),
                    _buildQuickInputField('Notes', 'How did it feel today?'),
                    const SizedBox(height: 16),
                    _buildQuickInputField('Practice Time (minutes)', '30'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  // TODO: Save journal entry
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Practice session recorded!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'Save Entry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickInputField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.deepPurpleAccent,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
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

// Data models
class JournalEntry {
  final DateTime date;
  final String raga;
  final String sur;
  final String taal;
  final String type;
  final String notes;
  final int pitchAccuracy;
  final int practiceTime;

  JournalEntry({
    required this.date,
    required this.raga,
    required this.sur,
    required this.taal,
    required this.type,
    required this.notes,
    required this.pitchAccuracy,
    required this.practiceTime,
  });
}

class RagaData {
  final String name;
  final String level;
  final String description;
  final List<String> notes;
  final String aarohAudioPath;
  final String avrohAudioPath;
  final String swarmalikaAudioPath;

  RagaData({
    required this.name,
    required this.level,
    required this.description,
    required this.notes,
    required this.aarohAudioPath,
    required this.avrohAudioPath,
    required this.swarmalikaAudioPath,
  });
}

class AudioFeedback {
  final double pitchAccuracy;
  final double tempoAccuracy;
  final List<String> missedNotes;
  final List<String> suggestions;
  final String overallFeedback;

  AudioFeedback({
    required this.pitchAccuracy,
    required this.tempoAccuracy,
    required this.missedNotes,
    required this.suggestions,
    required this.overallFeedback,
  });
}

class PracticeGoal {
  final String title;
  final String description;
  final int targetDays;
  int completedDays;
  final String raga;
  final DateTime deadline;

  PracticeGoal({
    required this.title,
    required this.description,
    required this.targetDays,
    required this.completedDays,
    required this.raga,
    required this.deadline,
  });
}

class PracticeSession {
  final DateTime date;
  final String raga;
  final String type;
  final List<MissedNote> missedNotes;
  final int tempo;
  final int pitchAccuracy;
  final int practiceTime;

  PracticeSession({
    required this.date,
    required this.raga,
    required this.type,
    required this.missedNotes,
    required this.tempo,
    required this.pitchAccuracy,
    required this.practiceTime,
  });
}

class MissedNote {
  final String note;
  final int count;
  final String expectedPitch;
  final String actualPitch;

  MissedNote({
    required this.note,
    required this.count,
    required this.expectedPitch,
    required this.actualPitch,
  });
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Nothing yet!',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}

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
