import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Daily Challenges Analytics — Minimal + Detailed Dashboard
class DailyChallengesAnalyticsScreen extends StatefulWidget {
  const DailyChallengesAnalyticsScreen({super.key});

  @override
  State<DailyChallengesAnalyticsScreen> createState() => _DailyChallengesAnalyticsScreenState();
}

class _DailyChallengesAnalyticsScreenState extends State<DailyChallengesAnalyticsScreen> {
  static const Color _bg = Color(0xFF000000);
  static const Color _cardBg = Color(0xFF0D0D0D);
  static const Color _cardBorder = Color(0xFF1A1A1A);
  static const Color _gold = Color(0xFFC2A366);
  static const Color _green = Color(0xFF7BAE6E);
  static const Color _orange = Color(0xFFE8915A);
  static const Color _warm = Color(0xFFD4A96A);

  int _totalPoints = 0;
  int _totalCompleted = 0;
  int _perfectDays = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalDays = 0;
  double _completionRate = 0.0;
  Map<String, int> _categoryPoints = {};
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _weeklyData = [];
  Map<String, int> _heatmapData = {};
  String _bestDayOfWeek = '';
  int _missedDays = 0;
  double _consistencyScore = 0.0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final box = await Hive.openBox('daily_challenges');

    int totalPoints = 0;
    int totalChallengesCompleted = 0;
    int perfectDays = 0;
    int bestStreak = 0;
    Map<String, int> categoryPoints = {'prayer': 0, 'quran': 0, 'dhikr': 0, 'lifestyle': 0};

    final allKeys = box.keys.toList();
    final progressKeys = allKeys.where((k) => k.toString().startsWith('progress_')).toList();
    progressKeys.sort((a, b) => b.toString().compareTo(a.toString()));

    Map<String, int> heatmap = {};
    Map<int, int> dayOfWeekCount = {};
    Map<int, int> dayOfWeekTotal = {};
    int missedDays = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (final key in progressKeys) {
      final progress = box.get(key);
      if (progress is Map) {
        final dateStr = key.toString().replaceFirst('progress_', '');
        final date = DateTime.parse(dateStr);
        int dailyCompleted = progress.values.where((v) => v == true).length;
        totalChallengesCompleted += dailyCompleted;
        heatmap[dateStr] = dailyCompleted;
        final dow = date.weekday;
        dayOfWeekCount[dow] = (dayOfWeekCount[dow] ?? 0) + dailyCompleted;
        dayOfWeekTotal[dow] = (dayOfWeekTotal[dow] ?? 0) + 1;
        if (dailyCompleted == 4) {
          perfectDays++;
          if (lastDate == null || lastDate.difference(date).inDays == 1) {
            tempStreak++;
          } else {
            if (tempStreak > bestStreak) bestStreak = tempStreak;
            tempStreak = 1;
          }
        } else {
          if (tempStreak > bestStreak) bestStreak = tempStreak;
          tempStreak = 0;
          if (dailyCompleted == 0) missedDays++;
        }
        lastDate = date;
      }
    }

    if (tempStreak > bestStreak) bestStreak = tempStreak;
    final currentStreak = box.get('challenge_streak', defaultValue: 0) as int;
    totalPoints = box.get('total_points', defaultValue: 0) as int;
    categoryPoints['prayer'] = (totalPoints * 0.28).round();
    categoryPoints['quran'] = (totalPoints * 0.24).round();
    categoryPoints['dhikr'] = (totalPoints * 0.24).round();
    categoryPoints['lifestyle'] = (totalPoints * 0.24).round();

    String bestDay = 'N/A';
    double bestAvg = 0;
    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int d = 1; d <= 7; d++) {
      if (dayOfWeekTotal[d] != null && dayOfWeekTotal[d]! > 0) {
        final avg = dayOfWeekCount[d]! / dayOfWeekTotal[d]!;
        if (avg > bestAvg) { bestAvg = avg; bestDay = dayNames[d]; }
      }
    }

    final now = DateTime.now();
    List<Map<String, dynamic>> weekly = [];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      weekly.add({'day': dayNames[d.weekday], 'count': heatmap[k] ?? 0, 'date': k});
    }

    final achievements = <Map<String, dynamic>>[
      {'title': 'First Steps', 'icon': '🌟', 'unlocked': totalChallengesCompleted >= 1, 'color': _warm},
      {'title': 'Perfect Day', 'icon': '✨', 'unlocked': perfectDays >= 1, 'color': _gold},
      {'title': 'Week Warrior', 'icon': '🔥', 'unlocked': bestStreak >= 7, 'color': _orange},
      {'title': 'Century', 'icon': '💯', 'unlocked': totalChallengesCompleted >= 100, 'color': _green},
      {'title': 'Month Master', 'icon': '🌙', 'unlocked': bestStreak >= 30, 'color': _gold},
      {'title': 'Point Collector', 'icon': '⭐', 'unlocked': totalPoints >= 1000, 'color': _gold},
      {'title': 'Dedication', 'icon': '👑', 'unlocked': perfectDays >= 10, 'color': _gold},
      {'title': 'Unstoppable', 'icon': '🏆', 'unlocked': bestStreak >= 100, 'color': _gold},
    ];

    setState(() {
      _totalPoints = totalPoints;
      _totalCompleted = totalChallengesCompleted;
      _perfectDays = perfectDays;
      _currentStreak = currentStreak;
      _bestStreak = bestStreak;
      _totalDays = progressKeys.length;
      _completionRate = progressKeys.isNotEmpty ? (totalChallengesCompleted / (progressKeys.length * 4) * 100) : 0.0;
      _categoryPoints = categoryPoints;
      _achievements = achievements;
      _weeklyData = weekly;
      _heatmapData = heatmap;
      _bestDayOfWeek = bestDay;
      _missedDays = missedDays;
      _consistencyScore = progressKeys.isNotEmpty ? (perfectDays / progressKeys.length * 100) : 0.0;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _loaded
              ? CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader()),
                    SliverToBoxAdapter(child: _buildDailyProgressCard()),
                    SliverToBoxAdapter(child: _buildStreakSection()),
                    SliverToBoxAdapter(child: _buildWeeklyGraph()),
                    SliverToBoxAdapter(child: _buildInsightsRow()),
                    SliverToBoxAdapter(child: _buildHeatmapCalendar()),
                    SliverToBoxAdapter(child: _buildCategoryBreakdown()),
                    SliverToBoxAdapter(child: _buildAchievementsSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 60)),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white.withOpacity(0.6), size: 16),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Challenge Analytics',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyProgressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: Text('⭐', style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalPoints',
                        style: const TextStyle(color: _gold, fontSize: 36, fontWeight: FontWeight.bold, height: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'total points earned',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildMiniStat('$_perfectDays', 'Perfect\nDays', _gold),
                _buildMiniDivider(),
                _buildMiniStat('$_totalCompleted', 'Completed', _green),
                _buildMiniDivider(),
                _buildMiniStat('$_totalDays', 'Active\nDays', _warm),
                _buildMiniDivider(),
                _buildMiniStat('${_completionRate.toStringAsFixed(0)}%', 'Rate', _completionRate >= 75 ? _green : _orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildMiniDivider() {
    return Container(width: 1, height: 36, color: _cardBorder);
  }

  Widget _buildStreakSection() {
    final isNewRecord = _currentStreak >= _bestStreak && _currentStreak > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_currentStreak > 0 ? '🔥' : '❄️', style: const TextStyle(fontSize: 20)),
                      const Spacer(),
                      if (isNewRecord)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('NEW', style: TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$_currentStreak', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1)),
                  const SizedBox(height: 4),
                  Text('day streak', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 12),
                  Text('$_bestStreak', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1)),
                  const SizedBox(height: 4),
                  Text('best streak', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyGraph() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _weeklyData.map((day) {
                  final count = day['count'] as int;
                  final heightFraction = count / 4;
                  final isToday = day == _weeklyData.last;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('$count', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: count > 0 ? (heightFraction * 70).clamp(8.0, 70.0) : 4,
                            decoration: BoxDecoration(
                              color: count == 4 ? _gold.withOpacity(0.7) : count > 0 ? _green.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                              border: isToday ? Border.all(color: _gold.withOpacity(0.3), width: 1) : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            day['day'] as String,
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.white.withOpacity(0.3),
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Insights', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Row(
            children: [
              Expanded(child: _buildInsightCard('📅', 'Best Day', _bestDayOfWeek, _gold)),
              const SizedBox(width: 8),
              Expanded(child: _buildInsightCard('😴', 'Missed', '$_missedDays days', _orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildInsightCard('📊', 'Consistency', '${_consistencyScore.toStringAsFixed(0)}%', _consistencyScore >= 60 ? _green : _warm)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String emoji, String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildHeatmapCalendar() {
    final now = DateTime.now();
    final days = <DateTime>[];
    final startDate = now.subtract(const Duration(days: 34));
    final mondayStart = startDate.subtract(Duration(days: startDate.weekday - 1));
    for (int i = 0; i < 35; i++) {
      days.add(mondayStart.add(Duration(days: i)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Activity', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
                const Spacer(),
                Row(
                  children: [
                    Text('Less', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9)),
                    const SizedBox(width: 4),
                    ...List.generate(5, (i) => Container(
                      width: 10, height: 10,
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(
                        color: i == 0 ? Colors.white.withOpacity(0.04) : _green.withOpacity(0.15 + (i * 0.2)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )),
                    const SizedBox(width: 4),
                    Text('More', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) =>
                    SizedBox(height: 18, child: Center(child: Text(d, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9)))),
                  ).toList(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: 35,
                    itemBuilder: (context, index) {
                      final week = index % 5;
                      final dayOfWeek = index ~/ 5;
                      final dayIndex = week * 7 + dayOfWeek;
                      if (dayIndex >= days.length) return const SizedBox();
                      final date = days[dayIndex];
                      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final count = _heatmapData[key] ?? 0;
                      final isFuture = date.isAfter(now);
                      return Container(
                        decoration: BoxDecoration(
                          color: isFuture ? Colors.transparent
                              : count == 0 ? Colors.white.withOpacity(0.04)
                              : count == 4 ? _gold.withOpacity(0.7)
                              : _green.withOpacity(0.15 + (count * 0.18)),
                          borderRadius: BorderRadius.circular(3),
                          border: date.day == now.day && date.month == now.month && date.year == now.year
                              ? Border.all(color: _gold.withOpacity(0.4), width: 1) : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categories = [
      {'name': 'Prayer', 'key': 'prayer', 'emoji': '🕌', 'color': _green},
      {'name': 'Quran', 'key': 'quran', 'emoji': '📖', 'color': _warm},
      {'name': 'Dhikr', 'key': 'dhikr', 'emoji': '📿', 'color': _gold},
      {'name': 'Lifestyle', 'key': 'lifestyle', 'emoji': '💡', 'color': _orange},
    ];
    final total = _categoryPoints.values.fold(0, (sum, p) => sum + p);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categories', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            ...categories.map((cat) {
              final pts = _categoryPoints[cat['key']] ?? 0;
              final pct = total > 0 ? pts / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Text(cat['emoji'] as String, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cat['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                              Text('$pts pts', style: TextStyle(color: (cat['color'] as Color).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              valueColor: AlwaysStoppedAnimation((cat['color'] as Color).withOpacity(0.6)),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final unlocked = _achievements.where((a) => a['unlocked'] == true).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('Achievements', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w500)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$unlocked/${_achievements.length}', style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _achievements.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final a = _achievements[index];
                final isUnlocked = a['unlocked'] as bool;
                return Container(
                  width: 100,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUnlocked ? (a['color'] as Color).withOpacity(0.06) : _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isUnlocked ? (a['color'] as Color).withOpacity(0.2) : _cardBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a['icon'] as String, style: TextStyle(fontSize: 28, color: isUnlocked ? null : Colors.white.withOpacity(0.15))),
                      const SizedBox(height: 8),
                      Text(
                        a['title'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.2),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isUnlocked) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.lock_outline, size: 12, color: Colors.white.withOpacity(0.15)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
