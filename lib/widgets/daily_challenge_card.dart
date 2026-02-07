import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/daily_challenges_analytics_screen.dart';

/// Daily Islamic Challenge Card
/// 
/// Design Science Principles:
/// 1. Gamification - Daily challenges create habit formation
/// 2. Variable Rewards - Different challenges keep users engaged
/// 3. Commitment & Consistency - Daily streaks build habits
/// 4. Endowed Progress - Visual completion encourages finishing
/// 5. Social Proof - Challenge completion stats motivate
class DailyIslamicChallengeCard extends ConsumerStatefulWidget {
  const DailyIslamicChallengeCard({super.key});

  @override
  ConsumerState<DailyIslamicChallengeCard> createState() => _DailyIslamicChallengeCardState();
}

class _DailyIslamicChallengeCardState extends ConsumerState<DailyIslamicChallengeCard> {
  Map<String, bool> _todayChallenges = {};
  int _challengeStreak = 0;
  List<Map<String, dynamic>> _dailyChallenges = [];
  
  // 🐪 Camel-brand design colors
  static const Color _primaryGreen = Color(0xFF7BAE6E);   // Oasis green
  static const Color _goldReward = Color(0xFFC2A366);     // Camel sand gold
  static const Color _tealProgress = Color(0xFFD4A96A);   // Desert warm
  static const Color _purpleSpirit = Color(0xFF9C27B0);
  static const Color _cardBg = Color(0xFF161B22);

  @override
  void initState() {
    super.initState();
    _generateDailyChallenges();
    _loadProgress();
  }

  void _generateDailyChallenges() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final random = Random(dayOfYear); // Same challenges for same day
    
    final allChallenges = [
      // Prayer challenges
      {'id': 'fajr_time', 'type': 'prayer', 'title': 'Pray Fajr on time', 'icon': '🌅', 'points': 30, 'reward': 'Start your day blessed'},
      {'id': 'all_prayers', 'type': 'prayer', 'title': 'Complete all 5 prayers', 'icon': '🕌', 'points': 50, 'reward': 'Perfect prayer day'},
      {'id': 'sunnah_prayers', 'type': 'prayer', 'title': 'Pray 4 Sunnah prayers', 'icon': '✨', 'points': 25, 'reward': 'Extra rewards'},
      
      // Quran challenges
      {'id': 'quran_page', 'type': 'quran', 'title': 'Read 1 page of Quran', 'icon': '📖', 'points': 20, 'reward': '10 hasanah per letter'},
      {'id': 'quran_surah', 'type': 'quran', 'title': 'Complete a Surah', 'icon': '📚', 'points': 35, 'reward': 'Surah completion'},
      {'id': 'ayatul_kursi', 'type': 'quran', 'title': 'Recite Ayatul Kursi 3x', 'icon': '🛡️', 'points': 15, 'reward': 'Protection'},
      
      // Dhikr challenges
      {'id': 'morning_adhkar', 'type': 'dhikr', 'title': 'Complete morning adhkar', 'icon': '🌄', 'points': 25, 'reward': 'Day protection'},
      {'id': 'evening_adhkar', 'type': 'dhikr', 'title': 'Complete evening adhkar', 'icon': '🌙', 'points': 25, 'reward': 'Night protection'},
      {'id': 'tasbih_100', 'type': 'dhikr', 'title': '100 SubhanAllah', 'icon': '📿', 'points': 20, 'reward': 'Tree in Jannah'},
      {'id': 'istighfar_100', 'type': 'dhikr', 'title': '100 Astaghfirullah', 'icon': '🤲', 'points': 20, 'reward': 'Sins forgiven'},
      
      // Lifestyle challenges
      {'id': 'no_social', 'type': 'lifestyle', 'title': 'No social media for 2 hours', 'icon': '📵', 'points': 30, 'reward': 'Digital detox'},
      {'id': 'good_deed', 'type': 'lifestyle', 'title': 'Do a secret good deed', 'icon': '💝', 'points': 25, 'reward': 'Sadaqah reward'},
      {'id': 'learn_deen', 'type': 'lifestyle', 'title': 'Learn something Islamic', 'icon': '🎓', 'points': 20, 'reward': 'Knowledge seeker'},
      {'id': 'help_someone', 'type': 'lifestyle', 'title': 'Help a fellow Muslim', 'icon': '🤝', 'points': 25, 'reward': 'Brotherhood'},
    ];
    
    // Shuffle and pick 4 challenges for today (1 from each category ideally)
    final categories = ['prayer', 'quran', 'dhikr', 'lifestyle'];
    _dailyChallenges = [];
    
    for (final category in categories) {
      final categoryList = allChallenges.where((c) => c['type'] == category).toList();
      categoryList.shuffle(random);
      if (categoryList.isNotEmpty) {
        _dailyChallenges.add(categoryList.first);
      }
    }
  }

  Future<void> _loadProgress() async {
    try {
      final box = await Hive.openBox('daily_challenges');
      final today = DateTime.now().toIso8601String().split('T')[0];
      final savedProgress = box.get('progress_$today');
      
      if (savedProgress != null && savedProgress is Map) {
        setState(() {
          _todayChallenges = Map<String, bool>.from(savedProgress);
        });
      }
      
      final streak = box.get('challenge_streak', defaultValue: 0);
      setState(() => _challengeStreak = streak);
    } catch (_) {}
  }

  Future<void> _toggleChallenge(String id) async {
    HapticFeedback.mediumImpact();
    
    try {
      final box = await Hive.openBox('daily_challenges');
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final newValue = !(_todayChallenges[id] ?? false);
      _todayChallenges[id] = newValue;
      
      await box.put('progress_$today', _todayChallenges);
      
      // Update total points
      if (newValue) {
        final challenge = _dailyChallenges.firstWhere((c) => c['id'] == id);
        final currentTotal = box.get('total_points', defaultValue: 0);
        await box.put('total_points', currentTotal + (challenge['points'] as int));
      } else {
        final challenge = _dailyChallenges.firstWhere((c) => c['id'] == id);
        final currentTotal = box.get('total_points', defaultValue: 0);
        await box.put('total_points', currentTotal - (challenge['points'] as int));
      }
      
      setState(() {});
      
      // Check if all challenges completed
      final allCompleted = _dailyChallenges.every((c) => _todayChallenges[c['id']] == true);
      if (allCompleted && newValue) {
        HapticFeedback.heavyImpact();
        
        // Update streak
        final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
        final yesterdayProgress = box.get('progress_$yesterday');
        
        int newStreak = 1;
        if (yesterdayProgress is Map && yesterdayProgress.values.every((v) => v == true)) {
          // Yesterday was perfect too
          newStreak = _challengeStreak + 1;
        }
        
        await box.put('challenge_streak', newStreak);
        setState(() => _challengeStreak = newStreak);
        
        _showCompletionReward();
      }
    } catch (_) {}
  }

  void _showCompletionReward() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _goldReward.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: _goldReward.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'All Challenges Complete!',
                style: TextStyle(
                  color: _goldReward,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'MashaAllah! You earned ${_calculateTotalPoints()} points today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      '${_challengeStreak + 1} day streak!',
                      style: TextStyle(
                        color: _primaryGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primaryGreen, Color(0xFFA67B5B)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Alhamdulillah!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateTotalPoints() {
    int total = 0;
    for (final challenge in _dailyChallenges) {
      if (_todayChallenges[challenge['id']] == true) {
        total += challenge['points'] as int;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _todayChallenges.values.where((v) => v).length;
    final totalCount = _dailyChallenges.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final allComplete = completedCount == totalCount && totalCount > 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DailyChallengesAnalyticsScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: allComplete
                ? [_goldReward.withOpacity(0.12), _cardBg]
                : [_cardBg, const Color(0xFF0D1117)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: allComplete
                ? _goldReward.withOpacity(0.3)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: allComplete
                            ? [_goldReward, _goldReward.withOpacity(0.7)]
                            : [_tealProgress, _tealProgress.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      allComplete ? Icons.emoji_events : Icons.flag,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        children: [
                          const Text(
                            'Daily Challenges',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (allComplete) ...[
                            const SizedBox(width: 8),
                            const Text('✨', style: TextStyle(fontSize: 14)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            allComplete
                                ? 'All challenges completed!'
                                : '${totalCount - completedCount} challenges remaining',
                            style: TextStyle(
                              color: allComplete
                                  ? _goldReward.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.trending_up,
                            color: _tealProgress.withOpacity(0.6),
                            size: 14,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Points badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _primaryGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${_calculateTotalPoints()}',
                        style: TextStyle(
                          color: _primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Challenge dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _dailyChallenges.map((challenge) {
                    final isComplete = _todayChallenges[challenge['id']] == true;
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isComplete
                            ? _primaryGreen
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isComplete
                              ? _primaryGreen
                              : Colors.white.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: isComplete
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(
                      allComplete ? _goldReward : _primaryGreen,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Challenge list
          ...List.generate(_dailyChallenges.length, (index) {
            final challenge = _dailyChallenges[index];
            final isComplete = _todayChallenges[challenge['id']] == true;
            
            return _buildChallengeRow(challenge, isComplete, index == _dailyChallenges.length - 1);
          }),
          
          // Streak footer
          if (_challengeStreak > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    '$_challengeStreak day streak',
                    style: TextStyle(
                      color: Colors.orange.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    ' • Keep it going!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
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

  Widget _buildChallengeRow(Map<String, dynamic> challenge, bool isComplete, bool isLast) {
    return GestureDetector(
      onTap: () => _toggleChallenge(challenge['id'] as String),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isComplete
              ? _primaryGreen.withOpacity(0.08)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: isLast ? null : Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Text(
              challenge['icon'] as String,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 14),
            
            // Title and reward
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge['title'] as String,
                    style: TextStyle(
                      color: isComplete
                          ? _primaryGreen
                          : Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: isComplete ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    challenge['reward'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Points
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isComplete
                    ? _primaryGreen.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${challenge['points']}',
                style: TextStyle(
                  color: isComplete ? _primaryGreen : Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isComplete ? _primaryGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isComplete ? _primaryGreen : Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
