import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Daily Challenges Analytics Dashboard
/// 
/// Gamification Psychology:
/// 1. Visual Progress - Charts and graphs
/// 2. Achievements - Unlock badges
/// 3. Streaks - Loss aversion
/// 4. Leaderboard - Social comparison (personal records)
/// 5. Historical data - Endowed progress effect
class DailyChallengesAnalyticsScreen extends StatefulWidget {
  const DailyChallengesAnalyticsScreen({super.key});

  @override
  State<DailyChallengesAnalyticsScreen> createState() => _DailyChallengesAnalyticsScreenState();
}

class _DailyChallengesAnalyticsScreenState extends State<DailyChallengesAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 🐪 Camel-brand colors
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _greenPrimary = Color(0xFF7BAE6E);   // Oasis green
  static const Color _goldReward = Color(0xFFC2A366);     // Camel sand gold
  static const Color _tealProgress = Color(0xFFD4A96A);   // Desert warm
  static const Color _purpleSpirit = Color(0xFF9C27B0);
  static const Color _orangeStreak = Color(0xFFE8915A);   // Desert sunset

  // Data
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _achievements = [];
  Map<String, int> _categoryPoints = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    final box = await Hive.openBox('daily_challenges');
    
    // Calculate statistics
    int totalPoints = 0;
    int totalChallengesCompleted = 0;
    int perfectDays = 0;
    int currentStreak = 0;
    int bestStreak = 0;
    Map<String, int> categoryPoints = {
      'prayer': 0,
      'quran': 0,
      'dhikr': 0,
      'lifestyle': 0,
    };
    
    final allKeys = box.keys.toList();
    final progressKeys = allKeys.where((k) => k.toString().startsWith('progress_')).toList();
    
    // Sort by date (newest first)
    progressKeys.sort((a, b) => b.toString().compareTo(a.toString()));
    
    // Calculate stats from historical data
    int tempStreak = 0;
    DateTime? lastDate;
    
    for (final key in progressKeys) {
      final progress = box.get(key);
      if (progress is Map) {
        final date = DateTime.parse(key.toString().replaceFirst('progress_', ''));
        
        // Count completed challenges
        int dailyCompleted = progress.values.where((v) => v == true).length;
        totalChallengesCompleted += dailyCompleted;
        
        if (dailyCompleted == 4) {
          perfectDays++;
          
          // Check streak
          if (lastDate == null || date.difference(lastDate).inDays == 1) {
            tempStreak++;
          } else {
            if (tempStreak > bestStreak) bestStreak = tempStreak;
            tempStreak = 1;
          }
        } else {
          if (tempStreak > bestStreak) bestStreak = tempStreak;
          tempStreak = 0;
        }
        
        lastDate = date;
      }
    }
    
    if (tempStreak > bestStreak) bestStreak = tempStreak;
    currentStreak = box.get('challenge_streak', defaultValue: 0);
    
    // Calculate category-specific points (estimate based on typical points)
    totalPoints = box.get('total_points', defaultValue: 0);
    categoryPoints['prayer'] = (totalPoints * 0.28).round(); // ~28%
    categoryPoints['quran'] = (totalPoints * 0.24).round();  // ~24%
    categoryPoints['dhikr'] = (totalPoints * 0.24).round();  // ~24%
    categoryPoints['lifestyle'] = (totalPoints * 0.24).round(); // ~24%
    
    // Generate achievements
    final achievements = <Map<String, dynamic>>[
      {
        'id': 'first_challenge',
        'title': 'First Steps',
        'description': 'Complete your first challenge',
        'icon': '🌟',
        'unlocked': totalChallengesCompleted >= 1,
        'color': _tealProgress,
      },
      {
        'id': 'perfect_day',
        'title': 'Perfect Day',
        'description': 'Complete all 4 daily challenges',
        'icon': '✨',
        'unlocked': perfectDays >= 1,
        'color': _goldReward,
      },
      {
        'id': 'week_warrior',
        'title': 'Week Warrior',
        'description': 'Maintain a 7-day streak',
        'icon': '🔥',
        'unlocked': bestStreak >= 7,
        'color': _orangeStreak,
      },
      {
        'id': 'century',
        'title': 'Century',
        'description': 'Complete 100 challenges',
        'icon': '💯',
        'unlocked': totalChallengesCompleted >= 100,
        'color': _greenPrimary,
      },
      {
        'id': 'month_master',
        'title': 'Month Master',
        'description': 'Maintain a 30-day streak',
        'icon': '🌙',
        'unlocked': bestStreak >= 30,
        'color': _purpleSpirit,
      },
      {
        'id': 'point_collector',
        'title': 'Point Collector',
        'description': 'Earn 1,000 total points',
        'icon': '⭐',
        'unlocked': totalPoints >= 1000,
        'color': _goldReward,
      },
      {
        'id': 'dedication',
        'title': 'Dedication',
        'description': '10 perfect days',
        'icon': '👑',
        'unlocked': perfectDays >= 10,
        'color': _goldReward,
      },
      {
        'id': 'unstoppable',
        'title': 'Unstoppable',
        'description': '100-day streak',
        'icon': '🏆',
        'unlocked': bestStreak >= 100,
        'color': _goldReward,
      },
    ];
    
    setState(() {
      _stats = {
        'totalPoints': totalPoints,
        'totalCompleted': totalChallengesCompleted,
        'perfectDays': perfectDays,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'totalDays': progressKeys.length,
        'completionRate': progressKeys.isNotEmpty 
            ? (totalChallengesCompleted / (progressKeys.length * 4) * 100)
            : 0.0,
      };
      _achievements = achievements;
      _categoryPoints = categoryPoints;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildAchievementsTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Challenge Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your spiritual journey',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _greenPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _greenPrimary.withOpacity(0.3)),
        ),
        dividerColor: Colors.transparent,
        labelColor: _greenPrimary,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Achievements'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero stats
          _buildHeroStats(),
          const SizedBox(height: 20),
          
          // Streak card
          _buildStreakCard(),
          const SizedBox(height: 20),
          
          // Category breakdown
          const Text(
            'Category Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildCategoryBreakdown(),
          const SizedBox(height: 20),
          
          // Completion rate
          _buildCompletionRate(),
          const SizedBox(height: 20),
          
          // Quick stats grid
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _goldReward.withOpacity(0.15),
            _goldReward.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _goldReward.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 40)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_stats['totalPoints'] ?? 0}',
                    style: const TextStyle(
                      color: _goldReward,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total Points Earned',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat('🏆', '${_stats['perfectDays'] ?? 0}', 'Perfect Days'),
                _buildDivider(),
                _buildMiniStat('✅', '${_stats['totalCompleted'] ?? 0}', 'Completed'),
                _buildDivider(),
                _buildMiniStat('📅', '${_stats['totalDays'] ?? 0}', 'Active Days'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildStreakCard() {
    final currentStreak = _stats['currentStreak'] ?? 0;
    final bestStreak = _stats['bestStreak'] ?? 0;
    final isNewRecord = currentStreak >= bestStreak && currentStreak > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _orangeStreak.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  currentStreak > 0 ? '🔥' : '❄️',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$currentStreak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'day streak',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        if (isNewRecord) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _goldReward.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '🏆 NEW!',
                              style: TextStyle(
                                color: _goldReward,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isNewRecord && bestStreak > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Best: $bestStreak days',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                  if (currentStreak > 0 && bestStreak > currentStreak)
                    Text(
                      ' • ${bestStreak - currentStreak} more to beat!',
                      style: TextStyle(
                        color: _orangeStreak.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = [
      {'name': 'Prayer', 'key': 'prayer', 'icon': '🕌', 'color': _greenPrimary},
      {'name': 'Quran', 'key': 'quran', 'icon': '📖', 'color': _tealProgress},
      {'name': 'Dhikr', 'key': 'dhikr', 'icon': '📿', 'color': _purpleSpirit},
      {'name': 'Lifestyle', 'key': 'lifestyle', 'icon': '💡', 'color': _orangeStreak},
    ];

    final total = _categoryPoints.values.fold(0, (sum, points) => sum + points);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: categories.map((category) {
          final points = _categoryPoints[category['key']] ?? 0;
          final percentage = total > 0 ? (points / total) : 0.0;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      category['icon'] as String,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category['name'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$points pts',
                      style: TextStyle(
                        color: category['color'] as Color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(category['color'] as Color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompletionRate() {
    final rate = _stats['completionRate'] ?? 0.0;
    final color = rate >= 80 ? _greenPrimary : rate >= 50 ? _tealProgress : _orangeStreak;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Completion Rate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '${_stats['currentStreak'] ?? 0}',
            'Current Streak',
            '🔥',
            _orangeStreak,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '${_stats['bestStreak'] ?? 0}',
            'Best Streak',
            '🏆',
            _goldReward,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, String emoji, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    final unlockedCount = _achievements.where((a) => a['unlocked'] == true).length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unlocked $unlockedCount/${_achievements.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _goldReward.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${((unlockedCount / _achievements.length) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: _goldReward,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Achievement grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: _achievements.length,
            itemBuilder: (context, index) {
              final achievement = _achievements[index];
              final unlocked = achievement['unlocked'] as bool;
              
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: unlocked
                      ? (achievement['color'] as Color).withOpacity(0.1)
                      : _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: unlocked
                        ? (achievement['color'] as Color).withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      achievement['icon'] as String,
                      style: TextStyle(
                        fontSize: 48,
                        color: unlocked ? null : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      achievement['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: unlocked ? Colors.white : Colors.white.withOpacity(0.3),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      achievement['description'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: unlocked
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white.withOpacity(0.2),
                        fontSize: 11,
                      ),
                    ),
                    if (!unlocked) ...[
                      const SizedBox(height: 8),
                      Icon(
                        Icons.lock_outline,
                        color: Colors.white.withOpacity(0.2),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<Box>(
      future: Hive.openBox('daily_challenges'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final box = snapshot.data!;
        final allKeys = box.keys.toList();
        final progressKeys = allKeys
            .where((k) => k.toString().startsWith('progress_'))
            .toList()
          ..sort((a, b) => b.toString().compareTo(a.toString()));

        if (progressKeys.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📝', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'No history yet',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: progressKeys.length,
          itemBuilder: (context, index) {
            final key = progressKeys[index];
            final date = key.toString().replaceFirst('progress_', '');
            final progress = box.get(key) as Map;
            final completed = progress.values.where((v) => v == true).length;
            final isPerfect = completed == 4;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPerfect
                    ? _goldReward.withOpacity(0.08)
                    : _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPerfect
                      ? _goldReward.withOpacity(0.3)
                      : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPerfect
                          ? _goldReward.withOpacity(0.2)
                          : _greenPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPerfect ? '🏆' : '📅',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPerfect
                              ? 'All challenges completed!'
                              : '$completed/4 challenges completed',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress circles
                  Row(
                    children: List.generate(4, (i) {
                      return Container(
                        margin: const EdgeInsets.only(left: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i < completed
                              ? (isPerfect ? _goldReward : _greenPrimary)
                              : Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'Today';
    } else if (targetDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}
