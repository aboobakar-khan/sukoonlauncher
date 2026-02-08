import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../screens/daily_challenges_analytics_screen.dart';
import '../screens/dhikr_history_pro_dashboard_redesigned.dart';
import '../screens/productivity_hub_screen.dart';
import '../screens/deen_mode_entry_screen.dart';
import '../screens/minimalist_duas_screen.dart';
import '../features/quran/screens/surah_list_screen.dart';
import '../features/quran/screens/surah_reader_screen.dart';
import '../features/quran/models/surah.dart';
import '../features/hadith_dua/screens/hadith_dua_screen.dart';

/// Daily Islamic Challenge Card — Minimalist Redesign
/// 
/// Deep-link navigation: tapping actionable challenges opens the relevant screen
/// Minimalist gold-accent design matching app palette
class DailyIslamicChallengeCard extends ConsumerStatefulWidget {
  const DailyIslamicChallengeCard({super.key});

  @override
  ConsumerState<DailyIslamicChallengeCard> createState() => _DailyIslamicChallengeCardState();
}

class _DailyIslamicChallengeCardState extends ConsumerState<DailyIslamicChallengeCard> {
  Map<String, bool> _todayChallenges = {};
  int _challengeStreak = 0;
  List<Map<String, dynamic>> _dailyChallenges = [];
  
  static const _gold = Color(0xFFC2A366);
  static const _bg = Color(0xFF0D0D0D);

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
      {'id': 'fajr_time', 'type': 'prayer', 'title': 'Pray Fajr on time', 'icon': '🌅', 'points': 30, 'reward': 'Start your day blessed', 'action': 'none'},
      {'id': 'all_prayers', 'type': 'prayer', 'title': 'Complete all 5 prayers', 'icon': '🕌', 'points': 50, 'reward': 'Perfect prayer day', 'action': 'none'},
      {'id': 'sunnah_prayers', 'type': 'prayer', 'title': 'Pray 4 Sunnah prayers', 'icon': '✨', 'points': 25, 'reward': 'Extra rewards', 'action': 'none'},
      
      // Quran challenges
      {'id': 'quran_page', 'type': 'quran', 'title': 'Read 1 page of Quran', 'icon': '📖', 'points': 20, 'reward': '10 hasanah per letter', 'action': 'quran_list'},
      {'id': 'quran_surah', 'type': 'quran', 'title': 'Complete a Surah', 'icon': '📚', 'points': 35, 'reward': 'Surah completion', 'action': 'quran_list'},
      {'id': 'ayatul_kursi', 'type': 'quran', 'title': 'Recite Ayatul Kursi 3x', 'icon': '🛡️', 'points': 15, 'reward': 'Protection', 'action': 'ayatul_kursi'},
      {'id': 'read_hadith', 'type': 'quran', 'title': 'Read a hadith & reflect', 'icon': '📜', 'points': 15, 'reward': 'Knowledge seeker', 'action': 'hadith_dua'},
      
      // Dhikr challenges
      {'id': 'morning_adhkar', 'type': 'dhikr', 'title': 'Complete morning adhkar', 'icon': '🌄', 'points': 25, 'reward': 'Day protection', 'action': 'adhkar_morning'},
      {'id': 'evening_adhkar', 'type': 'dhikr', 'title': 'Complete evening adhkar', 'icon': '🌙', 'points': 25, 'reward': 'Night protection', 'action': 'adhkar_evening'},
      {'id': 'tasbih_100', 'type': 'dhikr', 'title': '100 SubhanAllah', 'icon': '📿', 'points': 20, 'reward': 'Tree in Jannah', 'action': 'dhikr_counter'},
      {'id': 'istighfar_100', 'type': 'dhikr', 'title': '100 Astaghfirullah', 'icon': '🤲', 'points': 20, 'reward': 'Sins forgiven', 'action': 'dhikr_counter'},
      {'id': 'make_dua', 'type': 'dhikr', 'title': 'Make dua for someone', 'icon': '💫', 'points': 15, 'reward': 'Angel says Ameen', 'action': 'duas'},
      {'id': 'names_allah', 'type': 'dhikr', 'title': 'Learn a Name of Allah', 'icon': '✨', 'points': 15, 'reward': 'Know your Lord', 'action': 'adhkar_names'},
      
      // Lifestyle challenges
      {'id': 'no_social', 'type': 'lifestyle', 'title': 'No social media 2 hrs', 'icon': '📵', 'points': 30, 'reward': 'Digital detox', 'action': 'app_blocker'},
      {'id': 'good_deed', 'type': 'lifestyle', 'title': 'Do a secret good deed', 'icon': '💝', 'points': 25, 'reward': 'Sadaqah reward', 'action': 'none'},
      {'id': 'learn_deen', 'type': 'lifestyle', 'title': 'Learn something Islamic', 'icon': '🎓', 'points': 20, 'reward': 'Knowledge seeker', 'action': 'hadith_dua'},
      {'id': 'help_someone', 'type': 'lifestyle', 'title': 'Help a fellow Muslim', 'icon': '🤝', 'points': 25, 'reward': 'Brotherhood', 'action': 'none'},
      {'id': 'deen_mode', 'type': 'lifestyle', 'title': 'Use Deen Mode 30 min', 'icon': '🕌', 'points': 30, 'reward': 'Spiritual focus', 'action': 'deen_mode'},
      {'id': 'pomodoro_session', 'type': 'lifestyle', 'title': 'Complete a focus session', 'icon': '⏱️', 'points': 20, 'reward': 'Productive day', 'action': 'pomodoro'},
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

  void _navigateToAction(String action) {
    HapticFeedback.lightImpact();
    Widget? screen;
    switch (action) {
      case 'quran_list':
        screen = const SurahListScreen();
        break;
      case 'ayatul_kursi':
        screen = SurahReaderScreen(
          surah: Surah(id: 2, name: 'البقرة', transliteration: 'Al-Baqarah', type: 'Medinan', totalVerses: 286),
          initialAyah: 255,
        );
        break;
      case 'adhkar_morning':
        screen = const DhikrHistoryProDashboard(initialTab: 1, initialAdhkarSection: 0);
        break;
      case 'adhkar_evening':
        screen = const DhikrHistoryProDashboard(initialTab: 1, initialAdhkarSection: 1);
        break;
      case 'adhkar_names':
        screen = const DhikrHistoryProDashboard(initialTab: 1, initialAdhkarSection: 2);
        break;
      case 'dhikr_counter':
        screen = const DhikrHistoryProDashboard();
        break;
      case 'app_blocker':
        screen = const ProductivityHubScreen();
        break;
      case 'deen_mode':
        screen = const DeenModeEntryScreen();
        break;
      case 'pomodoro':
        screen = const ProductivityHubScreen();
        break;
      case 'hadith_dua':
        screen = const HadithDuaScreen();
        break;
      case 'duas':
        screen = const MinimalistDuasScreen();
        break;
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
  }

  void _showCompletionReward() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.emoji_events_rounded, color: _gold, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'All Complete!',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'You earned ${_calculateTotalPoints()} points today',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              if (_challengeStreak > 0) ...[
                const SizedBox(height: 14),
                Text(
                  '🔥 ${_challengeStreak + 1} day streak',
                  style: TextStyle(color: _gold.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Alhamdulillah',
                    style: TextStyle(color: Color(0xFF0D0D0D), fontWeight: FontWeight.w600, fontSize: 14),
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
    for (final c in _dailyChallenges) {
      if (_todayChallenges[c['id']] == true) total += c['points'] as int;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _todayChallenges.values.where((v) => v).length;
    final totalCount = _dailyChallenges.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final allComplete = completedCount == totalCount && totalCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allComplete ? _gold.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // ── Header ──
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DailyChallengesAnalyticsScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Daily Challenges',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Streak badge
                  if (_challengeStreak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔥 $_challengeStreak',
                        style: TextStyle(color: _gold.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Spacer(),
                  // Points earned
                  Text(
                    '+${_calculateTotalPoints()} pts',
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.25), size: 18),
                ],
              ),
            ),
          ),

          // ── Progress bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(allComplete ? _gold : _gold.withValues(alpha: 0.6)),
                minHeight: 3,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── Challenge rows ──
          ...List.generate(_dailyChallenges.length, (i) {
            final challenge = _dailyChallenges[i];
            final isComplete = _todayChallenges[challenge['id']] == true;
            return _buildChallengeRow(challenge, isComplete);
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildChallengeRow(Map<String, dynamic> challenge, bool isComplete) {
    final action = challenge['action'] as String? ?? 'none';
    final hasAction = action != 'none';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => _toggleChallenge(challenge['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: isComplete ? _gold : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isComplete ? _gold : Colors.white.withValues(alpha: 0.15),
                  width: 1.5,
                ),
              ),
              child: isComplete ? const Icon(Icons.check_rounded, color: Color(0xFF0D0D0D), size: 14) : null,
            ),
          ),
          const SizedBox(width: 10),

          // Title — tappable if actionable
          Expanded(
            child: GestureDetector(
              onTap: hasAction && !isComplete ? () => _navigateToAction(action) : () => _toggleChallenge(challenge['id'] as String),
              child: Text(
                challenge['title'] as String,
                style: TextStyle(
                  color: isComplete
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  decoration: isComplete ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),

          // Points
          Text(
            '+${challenge['points']}',
            style: TextStyle(
              color: isComplete ? _gold.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.25),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          // "Go" button for actionable + uncompleted
          if (hasAction && !isComplete) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _navigateToAction(action),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _gold.withValues(alpha: 0.35), width: 1),
                ),
                child: Text(
                  'Go',
                  style: TextStyle(color: _gold.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
