import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/prayer_provider.dart';
import '../providers/premium_provider.dart';
import '../models/prayer_record.dart';
import 'premium_paywall_screen.dart';

/// Prayer History Dashboard - PREMIUM FEATURE
/// Clean 3-tab design: Journey · Calendar · Badges
class PrayerHistoryDashboard extends ConsumerStatefulWidget {
  const PrayerHistoryDashboard({super.key});

  @override
  ConsumerState<PrayerHistoryDashboard> createState() => _PrayerHistoryDashboardState();
}

class _PrayerHistoryDashboardState extends ConsumerState<PrayerHistoryDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Camel brand palette
  static const Color _sand = Color(0xFFC2A366);
  static const Color _camel = Color(0xFFA67B5B);
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _card = Color(0xFF111111);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider).isPremium;
    if (!isPremium) return _buildLockedScreen(context);

    final recordsMap = ref.watch(prayerRecordsMapProvider);
    final records = ref.watch(prayerRecordListProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 4),
            _buildTabBar(),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _JourneyTab(recordsMap: recordsMap, records: records),
                  _CalendarTab(
                    recordsMap: recordsMap,
                    selectedYear: _selectedYear,
                    selectedMonth: _selectedMonth,
                    onMonthChanged: (y, m) => setState(() {
                      _selectedYear = y;
                      _selectedMonth = m;
                    }),
                  ),
                  _BadgesTab(recordsMap: recordsMap, records: records),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _sand.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline, color: _sand, size: 40),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Unlock Prayer Analytics',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track streaks, view insights, earn badges\nand deepen your spiritual journey',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_sand, _camel]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Upgrade to Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back, color: Colors.white.withOpacity(0.7), size: 20),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prayer Analytics', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                Text('Your spiritual journey', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_sand, _camel]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.star, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _sand.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        dividerColor: Colors.transparent,
        labelColor: _sand,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Journey'),
          Tab(text: 'Calendar'),
          Tab(text: 'Badges'),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// =============================================================================
// JOURNEY TAB - All stats, insights, and spiritual content in one flow
// =============================================================================
class _JourneyTab extends StatefulWidget {
  final Map<String, PrayerRecord> recordsMap;
  final List<PrayerRecord> records;
  const _JourneyTab({required this.recordsMap, required this.records});

  @override
  State<_JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<_JourneyTab> {
  static const Color _sand = Color(0xFFC2A366);
  static const Color _camel = Color(0xFFA67B5B);
  static const Color _card = Color(0xFF111111);
  static const Color _teal = Color(0xFF26A69A);
  static const Color _purple = Color(0xFF7C4DFF);
  static const Color _gold = Color(0xFFFFD700);

  // Sunnah & spiritual state
  Map<String, bool> _todaySunnah = {};
  int _khushuRating = 0;
  String _dailyReflection = '';
  bool _showSpiritualSection = false;

  @override
  void initState() {
    super.initState();
    _loadSpiritualData();
  }

  Future<void> _loadSpiritualData() async {
    try {
      final box = await Hive.openBox('spiritual_data');
      final today = DateTime.now().toIso8601String().split('T')[0];
      final saved = box.get('sunnah_$today');
      if (saved != null && saved is Map) {
        setState(() => _todaySunnah = Map<String, bool>.from(saved));
      } else {
        _todaySunnah = {
          'tahajjud': false, 'fajr_sunnah': false, 'duha': false,
          'dhuhr_before': false, 'dhuhr_after': false, 'asr_before': false,
          'maghrib_after': false, 'isha_before': false, 'isha_after': false, 'witr': false,
        };
      }
      final k = box.get('khushu_$today');
      if (k != null) setState(() => _khushuRating = k as int);
      final r = box.get('reflection_$today');
      if (r != null) setState(() => _dailyReflection = r as String);
    } catch (_) {}
  }

  Future<void> _saveSpiritualData() async {
    try {
      final box = await Hive.openBox('spiritual_data');
      final today = DateTime.now().toIso8601String().split('T')[0];
      await box.put('sunnah_$today', _todaySunnah);
      await box.put('khushu_$today', _khushuRating);
      await box.put('reflection_$today', _dailyReflection);
    } catch (_) {}
  }

  Map<String, dynamic> _calcStats() {
    int currentStreak = 0, bestStreak = 0, tempStreak = 0;
    int totalPrayers = 0, perfectDays = 0;
    bool streakRisk = false;
    final prayerCounts = <String, int>{'Fajr': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0};

    final sorted = widget.recordsMap.keys.toList()..sort();
    for (int i = sorted.length - 1; i >= 0; i--) {
      final r = widget.recordsMap[sorted[i]];
      if (r != null) {
        totalPrayers += r.completedCount;
        if (r.completedCount == 5) perfectDays++;
        if (r.fajr) prayerCounts['Fajr'] = (prayerCounts['Fajr'] ?? 0) + 1;
        if (r.dhuhr) prayerCounts['Dhuhr'] = (prayerCounts['Dhuhr'] ?? 0) + 1;
        if (r.asr) prayerCounts['Asr'] = (prayerCounts['Asr'] ?? 0) + 1;
        if (r.maghrib) prayerCounts['Maghrib'] = (prayerCounts['Maghrib'] ?? 0) + 1;
        if (r.isha) prayerCounts['Isha'] = (prayerCounts['Isha'] ?? 0) + 1;
        if (r.completedCount >= 3) {
          tempStreak++;
          if (i == sorted.length - 1 || i == sorted.length - 2) currentStreak = tempStreak;
        } else {
          if (tempStreak > bestStreak) bestStreak = tempStreak;
          tempStreak = 0;
        }
      }
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;

    final todayKey = _fmtDate(DateTime.now());
    final todayRec = widget.recordsMap[todayKey];
    streakRisk = currentStreak > 0 && (todayRec == null || todayRec.completedCount < 3);

    return {
      'currentStreak': currentStreak, 'bestStreak': bestStreak,
      'totalPrayers': totalPrayers, 'perfectDays': perfectDays,
      'totalDays': widget.recordsMap.length,
      'averagePerDay': widget.recordsMap.isEmpty ? 0.0 : totalPrayers / widget.recordsMap.length,
      'consistencyPercent': widget.recordsMap.isEmpty ? 0.0 : (perfectDays / widget.recordsMap.length * 100),
      'streakRisk': streakRisk, 'prayerCounts': prayerCounts,
    };
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final stats = _calcStats();
    final insights = _generateInsights(stats);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Hero Stats ───
          _buildHeroStats(stats),
          const SizedBox(height: 16),

          // ─── Streak ───
          _buildStreakCard(stats),
          const SizedBox(height: 20),

          // ─── This Week ───
          _label('THIS WEEK'),
          const SizedBox(height: 10),
          _buildWeeklyBars(),
          const SizedBox(height: 20),

          // ─── Prayer Breakdown + Grade ───
          _label('PRAYER BREAKDOWN'),
          const SizedBox(height: 10),
          _buildPrayerBreakdown(stats),
          const SizedBox(height: 16),
          _buildConsistencyGrade(stats),
          const SizedBox(height: 20),

          // ─── Insights ───
          if (insights.isNotEmpty) ...[
            _label('INSIGHTS'),
            const SizedBox(height: 10),
            ...insights.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildInsightRow(i),
            )),
            const SizedBox(height: 12),
          ],

          // ─── Recent Activity ───
          _label('RECENT ACTIVITY'),
          const SizedBox(height: 10),
          _buildRecentActivity(),
          const SizedBox(height: 20),

          // ─── Spiritual Section (expandable) ───
          _buildSpiritualToggle(),
          if (_showSpiritualSection) ...[
            const SizedBox(height: 16),
            _buildDailyVerse(),
            const SizedBox(height: 16),
            _buildKhushuSection(),
            const SizedBox(height: 16),
            _buildSunnahTracker(),
            const SizedBox(height: 16),
            _buildReflectionCard(),
          ],
        ],
      ),
    );
  }

  // ─── HERO STATS ───
  Widget _buildHeroStats(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_sand.withOpacity(0.12), _sand.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _sand.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _heroStat('${stats['totalPrayers']}', 'Total Prayers', '🕌'),
          Container(width: 1, height: 44, color: Colors.white.withOpacity(0.08)),
          _heroStat('${stats['perfectDays']}', 'Perfect Days', '✨'),
          Container(width: 1, height: 44, color: Colors.white.withOpacity(0.08)),
          _heroStat((stats['averagePerDay'] as double).toStringAsFixed(1), 'Daily Avg', '📊'),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ],
    );
  }

  // ─── STREAK ───
  Widget _buildStreakCard(Map<String, dynamic> stats) {
    final streak = stats['currentStreak'] as int;
    final best = stats['bestStreak'] as int;
    final risk = stats['streakRisk'] as bool;
    final isRecord = streak >= best && streak > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: risk ? Colors.orange.withOpacity(0.08) : _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: risk ? Colors.orange.withOpacity(0.25) : Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Text(streak > 0 ? '🔥' : '❄️', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('$streak', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Text('day streak', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                    if (isRecord) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: _gold.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                        child: const Text('🏆 BEST', style: TextStyle(color: Color(0xFFFFD700), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (risk)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('⚠️ Don\'t lose your streak! Pray now 🤲',
                      style: TextStyle(color: Colors.orange.shade300, fontSize: 11)),
                  ),
                if (!isRecord && best > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Best: $best days • ${best - streak} more to beat!',
                      style: TextStyle(color: _sand.withOpacity(0.6), fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── WEEKLY BARS ───
  Widget _buildWeeklyBars() {
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key = _fmtDate(d);
      return widget.recordsMap[key]?.completedCount ?? 0;
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final count = days[i];
          final isToday = i == 6;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Text('$count', style: TextStyle(
                    color: count == 5 ? _sand : Colors.white.withOpacity(0.5),
                    fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                  const SizedBox(height: 6),
                  Container(
                    height: 6 + (count / 5 * 50),
                    decoration: BoxDecoration(
                      gradient: count > 0 ? LinearGradient(
                        colors: [_sand.withOpacity(0.5 + count / 10), _sand],
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      ) : null,
                      color: count == 0 ? Colors.white.withOpacity(0.05) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(weekDays[i], style: TextStyle(
                    color: isToday ? _sand : Colors.white.withOpacity(0.3),
                    fontSize: 11, fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  )),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── PRAYER BREAKDOWN ───
  Widget _buildPrayerBreakdown(Map<String, dynamic> stats) {
    final counts = stats['prayerCounts'] as Map<String, int>;
    final total = widget.recordsMap.length;
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: prayers.map((p) {
          final count = counts[p] ?? 0;
          final pct = total > 0 ? (count / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(p, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation(_sand.withOpacity(0.4 + pct / 200)),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 36, child: Text('${pct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: pct >= 80 ? _sand : pct >= 50 ? Colors.orange : Colors.red.shade300,
                    fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── CONSISTENCY GRADE ───
  Widget _buildConsistencyGrade(Map<String, dynamic> stats) {
    final pct = stats['consistencyPercent'] as double;
    String grade;
    if (pct >= 90) { grade = 'A+'; }
    else if (pct >= 80) { grade = 'A'; }
    else if (pct >= 70) { grade = 'B+'; }
    else if (pct >= 60) { grade = 'B'; }
    else if (pct >= 50) { grade = 'C'; }
    else if (pct >= 40) { grade = 'D'; }
    else { grade = 'F'; }

    Color gc;
    switch (grade) {
      case 'A+': case 'A': gc = _sand; break;
      case 'B+': case 'B': gc = Colors.blue; break;
      case 'C': gc = Colors.orange; break;
      default: gc = Colors.red;
    }

    String msg;
    switch (grade) {
      case 'A+': msg = 'Outstanding! 🌟'; break;
      case 'A': msg = 'Excellent Work!'; break;
      case 'B+': msg = 'Great Progress!'; break;
      case 'B': msg = 'Good Job!'; break;
      case 'C': msg = 'Keep Improving'; break;
      case 'D': msg = 'You Can Do Better'; break;
      default: msg = 'Start Your Journey';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: gc.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gc.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [gc, gc.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(grade, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${pct.toStringAsFixed(0)}% perfect days', style: TextStyle(color: gc, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── INSIGHTS ───
  List<Map<String, String>> _generateInsights(Map<String, dynamic> stats) {
    final insights = <Map<String, String>>[];
    if (widget.recordsMap.isEmpty) return insights;

    final counts = stats['prayerCounts'] as Map<String, int>;
    final total = widget.recordsMap.length;
    final weakest = counts.entries.reduce((a, b) => a.value < b.value ? a : b);
    final strongest = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final perfectDays = stats['perfectDays'] as int;

    if (weakest.value < total * 0.5) {
      insights.add({'icon': '💡', 'msg': '${weakest.key} is your most missed prayer (${((weakest.value / total) * 100).toInt()}%). Try setting a reminder.'});
    }
    if (strongest.value >= total * 0.8) {
      insights.add({'icon': '⭐', 'msg': 'Great at ${strongest.key}! ${((strongest.value / total) * 100).toInt()}% consistency.'});
    }
    if (perfectDays > 0) {
      final pp = (perfectDays / total * 100).toInt();
      insights.add({'icon': pp >= 50 ? '🌟' : '🎯', 'msg': pp >= 50 ? 'MashaAllah! All 5 prayers on $pp% of days.' : '$perfectDays perfect days. Aim for all 5 daily!'});
    }
    insights.add({'icon': '📿', 'msg': '"The first thing a person will be accountable for is their Salah."'});
    return insights;
  }

  Widget _buildInsightRow(Map<String, String> insight) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight['icon']!, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(insight['msg']!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5))),
        ],
      ),
    );
  }

  // ─── RECENT ACTIVITY ───
  Widget _buildRecentActivity() {
    final recent = widget.records.take(5).toList();
    if (recent.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text('No recent activity', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
      );
    }

    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: recent.asMap().entries.map((e) {
          final r = e.value;
          final isLast = e.key == recent.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04)))),
            child: Row(
              children: [
                // Date
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: r.completedCount == 5 ? _sand.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${r.date.day}', style: TextStyle(color: r.completedCount == 5 ? _sand : Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(_monthAbbr(r.date.month), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Prayer dots
                ...List.generate(5, (pi) {
                  final labels = ['F', 'D', 'A', 'M', 'I'];
                  final done = [r.fajr, r.dhuhr, r.asr, r.maghrib, r.isha][pi];
                  return Container(
                    width: 24, height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: done ? _sand.withOpacity(0.25) : Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(color: done ? _sand : Colors.white.withOpacity(0.08), width: 1.5),
                    ),
                    child: done ? const Icon(Icons.check, size: 11, color: _sand) : Center(
                      child: Text(labels[pi], style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8)),
                    ),
                  );
                }),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: r.completedCount == 5 ? _sand.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${r.completedCount}/5', style: TextStyle(
                    color: r.completedCount == 5 ? _sand : Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── SPIRITUAL TOGGLE ───
  Widget _buildSpiritualToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showSpiritualSection = !_showSpiritualSection);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_teal.withOpacity(0.12), _purple.withOpacity(0.06)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _teal.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Text('🕌', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spiritual Journey', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Sunnah tracker, Khushu, Quranic verses & reflection',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ],
              ),
            ),
            Icon(_showSpiritualSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  // ─── DAILY VERSE ───
  Widget _buildDailyVerse() {
    final verses = [
      {'arabic': 'إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ', 'en': 'Indeed, prayer prohibits immorality and wrongdoing.', 'ref': 'Al-Ankabut 29:45'},
      {'arabic': 'وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ', 'en': 'And establish prayer and give zakah.', 'ref': 'Al-Baqarah 2:43'},
      {'arabic': 'حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلَاةِ الْوُسْطَىٰ', 'en': 'Maintain with care the prayers and the middle prayer.', 'ref': 'Al-Baqarah 2:238'},
      {'arabic': 'قَدْ أَفْلَحَ الْمُؤْمِنُونَ الَّذِينَ هُمْ فِي صَلَاتِهِمْ خَاشِعُونَ', 'en': 'Successful are the believers who are humble in their prayers.', 'ref': 'Al-Muminun 23:1-2'},
      {'arabic': 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ', 'en': 'And seek help through patience and prayer.', 'ref': 'Al-Baqarah 2:45'},
      {'arabic': 'إِنَّ الصَّلَاةَ كَانَتْ عَلَى الْمُؤْمِنِينَ كِتَابًا مَّوْقُوتًا', 'en': 'Prayer has been decreed upon the believers at specified times.', 'ref': 'An-Nisa 4:103'},
      {'arabic': 'وَأَقِمِ الصَّلَاةَ لِذِكْرِي', 'en': 'And establish prayer for My remembrance.', 'ref': 'Ta-Ha 20:14'},
    ];
    final v = verses[DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays % verses.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.menu_book, color: _gold.withOpacity(0.8), size: 16),
            const SizedBox(width: 8),
            Text("Today's Reminder", style: TextStyle(color: _gold.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _gold.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
            child: Text(v['arabic']!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Amiri', height: 2)),
          ),
          const SizedBox(height: 10),
          Text('"${v['en']!}"', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontStyle: FontStyle.italic, height: 1.5)),
          const SizedBox(height: 4),
          Text(v['ref']!, style: TextStyle(color: _gold.withOpacity(0.5), fontSize: 11)),
        ],
      ),
    );
  }

  // ─── KHUSHU ───
  Widget _buildKhushuSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.self_improvement, color: _purple.withOpacity(0.8), size: 16),
            const SizedBox(width: 8),
            const Text('Khushu Rating', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('How focused were you?', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final sel = i < _khushuRating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _khushuRating = i + 1);
                  _saveSpiritualData();
                },
                child: Icon(sel ? Icons.favorite : Icons.favorite_border, color: sel ? _purple : Colors.white24, size: 28),
              );
            }),
          ),
          if (_khushuRating > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                ['Keep striving - Allah loves effort 💪', 'Progress is progress 🌱', 'MashaAllah, you are growing 🌿', 'Your heart is connecting ❤️', 'SubhanAllah - true presence ✨'][_khushuRating - 1],
                style: TextStyle(color: _purple.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── SUNNAH TRACKER ───
  Widget _buildSunnahTracker() {
    final sunnahs = [
      {'key': 'tahajjud', 'name': 'Tahajjud', 'info': 'Last third of night', 'icon': '🌙'},
      {'key': 'fajr_sunnah', 'name': 'Fajr Sunnah', 'info': '2 before Fajr', 'icon': '🌅'},
      {'key': 'duha', 'name': 'Duha', 'info': '15 min after sunrise', 'icon': '☀️'},
      {'key': 'dhuhr_before', 'name': 'Dhuhr Sunnah', 'info': '4 before + 2 after', 'icon': '🕐'},
      {'key': 'asr_before', 'name': 'Asr Sunnah', 'info': '4 before Asr', 'icon': '🌤️'},
      {'key': 'maghrib_after', 'name': 'Maghrib Sunnah', 'info': '2 after Maghrib', 'icon': '🌆'},
      {'key': 'isha_after', 'name': 'Isha Sunnah', 'info': '2 after Isha', 'icon': '🌃'},
      {'key': 'witr', 'name': 'Witr', 'info': 'Odd number after Isha', 'icon': '✨'},
    ];
    final done = _todaySunnah.values.where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(children: [
            const Text('Sunnah Prayers', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('$done/${sunnahs.length}', style: const TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 12),
          ...sunnahs.map((s) {
            final completed = _todaySunnah[s['key']] ?? false;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _todaySunnah[s['key']!] = !completed);
                _saveSpiritualData();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: completed ? _teal.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Text(s['icon']!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['name']!, style: TextStyle(color: completed ? _teal : Colors.white, fontSize: 13,
                          decoration: completed ? TextDecoration.lineThrough : null)),
                        Text(s['info']!, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: completed ? _teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: completed ? _teal : Colors.white24, width: 1.5),
                    ),
                    child: completed ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── REFLECTION ───
  Widget _buildReflectionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.edit_note, color: _teal.withOpacity(0.7), size: 16),
            const SizedBox(width: 8),
            Text('Daily Reflection', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: _dailyReflection,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'How did you feel in your prayers today?',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              filled: true, fillColor: Colors.white.withOpacity(0.03),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14),
            ),
            onChanged: (v) { _dailyReflection = v; _saveSpiritualData(); },
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ───
  Widget _label(String text) {
    return Text(text, style: TextStyle(
      color: Colors.white.withOpacity(0.35), fontSize: 12,
      fontWeight: FontWeight.w600, letterSpacing: 1.0,
    ));
  }

  String _monthAbbr(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

// =============================================================================
// CALENDAR TAB
// =============================================================================
class _CalendarTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;
  final int selectedYear;
  final int selectedMonth;
  final Function(int, int) onMonthChanged;

  const _CalendarTab({
    required this.recordsMap, required this.selectedYear,
    required this.selectedMonth, required this.onMonthChanged,
  });

  static const Color _sand = Color(0xFFC2A366);
  static const Color _card = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(children: [
        _buildMonthSelector(),
        const SizedBox(height: 16),
        _buildHeatMap(),
        const SizedBox(height: 16),
        _buildMonthSummary(),
      ]),
    );
  }

  Widget _buildMonthSelector() {
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onMonthChanged(selectedMonth == 1 ? selectedYear - 1 : selectedYear, selectedMonth == 1 ? 12 : selectedMonth - 1);
            },
            child: Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.5)),
          ),
          Column(children: [
            Text(months[selectedMonth - 1], style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            Text('$selectedYear', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
          ]),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final now = DateTime.now();
              if (selectedYear < now.year || (selectedYear == now.year && selectedMonth < now.month)) {
                onMonthChanged(selectedMonth == 12 ? selectedYear + 1 : selectedYear, selectedMonth == 12 ? 1 : selectedMonth + 1);
              }
            },
            child: Icon(Icons.chevron_right, color: (selectedYear < DateTime.now().year || (selectedYear == DateTime.now().year && selectedMonth < DateTime.now().month))
              ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.15)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatMap() {
    final firstDay = DateTime(selectedYear, selectedMonth, 1);
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;
    final startWD = firstDay.weekday;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
          child: Center(child: Text(d, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontWeight: FontWeight.w500))),
        )).toList()),
        const SizedBox(height: 10),
        ...List.generate((daysInMonth + startWD - 1) ~/ 7 + 1, (week) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: List.generate(7, (di) {
              final dayNum = week * 7 + di + 2 - startWD;
              if (dayNum < 1 || dayNum > daysInMonth) return Expanded(child: Container());
              final key = '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
              final count = recordsMap[key]?.completedCount ?? 0;
              final isToday = selectedYear == DateTime.now().year && selectedMonth == DateTime.now().month && dayNum == DateTime.now().day;
              return Expanded(
                child: Container(
                  height: 34, margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _heatColor(count), borderRadius: BorderRadius.circular(6),
                    border: isToday ? Border.all(color: Colors.white, width: 1.5) : null,
                  ),
                  child: Center(child: Text('$dayNum', style: TextStyle(
                    color: count >= 3 ? Colors.white : Colors.white.withOpacity(0.4),
                    fontSize: 11, fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ))),
                ),
              );
            })),
          );
        }),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendDot(Colors.white.withOpacity(0.05), '0'),
          _legendDot(_sand.withOpacity(0.25), '1-2'),
          _legendDot(_sand.withOpacity(0.5), '3-4'),
          _legendDot(_sand, '5'),
        ]),
      ]),
    );
  }

  Color _heatColor(int c) {
    if (c == 0) return Colors.white.withOpacity(0.05);
    if (c <= 2) return _sand.withOpacity(0.25);
    if (c <= 4) return _sand.withOpacity(0.5);
    return _sand;
  }

  Widget _legendDot(Color c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
      ]),
    );
  }

  Widget _buildMonthSummary() {
    int totalP = 0, perfect = 0, tracked = 0;
    recordsMap.forEach((key, r) {
      if (key.startsWith('$selectedYear-${selectedMonth.toString().padLeft(2, '0')}')) {
        totalP += r.completedCount;
        if (r.completedCount == 5) perfect++;
        tracked++;
      }
    });
    final avg = tracked > 0 ? totalP / tracked : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: _summaryItem('🕌', '$totalP', 'Prayers')),
        Expanded(child: _summaryItem('✨', '$perfect', 'Perfect Days')),
        Expanded(child: _summaryItem('📊', avg.toStringAsFixed(1), 'Daily Avg')),
      ]),
    );
  }

  Widget _summaryItem(String emoji, String val, String label) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
    ]);
  }
}

// =============================================================================
// BADGES TAB
// =============================================================================
class _BadgesTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;
  final List<PrayerRecord> records;
  const _BadgesTab({required this.recordsMap, required this.records});

  static const Color _sand = Color(0xFFC2A366);
  static const Color _card = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final achievements = _calcAchievements();
    final unlocked = achievements.where((a) => a['unlocked'] as bool).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progress header
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFFFFD700).withOpacity(0.12), const Color(0xFFFFD700).withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.15)),
          ),
          child: Column(children: [
            Row(children: [
              const Text('🏆', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$unlocked / ${achievements.length} Unlocked', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Keep going to unlock more!', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: unlocked / achievements.length,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        ...achievements.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildBadgeCard(a),
        )),
      ]),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> a) {
    final isUnlocked = a['unlocked'] as bool;
    final progress = a['progress'] as double;
    final rarity = a['rarity'] as String;
    final rc = _rarityColor(rarity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked ? rc.withOpacity(0.08) : _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnlocked ? rc.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isUnlocked ? rc.withOpacity(0.15) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(a['icon'] as String, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(a['title'] as String, style: TextStyle(color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: rc.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
              child: Text(rarity, style: TextStyle(color: rc, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(a['description'] as String, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          if (!isUnlocked && progress > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(rc.withOpacity(0.5)), minHeight: 3),
              )),
              const SizedBox(width: 6),
              Text('${(progress * 100).toInt()}%', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
            ]),
          ],
        ])),
        const SizedBox(width: 8),
        isUnlocked
          ? Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: rc.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.check, color: rc, size: 14),
            )
          : Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.15), size: 18),
      ]),
    );
  }

  Color _rarityColor(String r) {
    switch (r) {
      case 'Common': return Colors.grey;
      case 'Uncommon': return Colors.green;
      case 'Rare': return Colors.blue;
      case 'Epic': return Colors.purple;
      case 'Legendary': return const Color(0xFFFFD700);
      default: return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _calcAchievements() {
    int total = 0, perfect = 0, bestStreak = 0, tempStreak = 0, fajrCount = 0;
    for (final r in recordsMap.values) {
      total += r.completedCount;
      if (r.completedCount == 5) perfect++;
      if (r.fajr) fajrCount++;
      if (r.completedCount >= 3) { tempStreak++; } else { if (tempStreak > bestStreak) bestStreak = tempStreak; tempStreak = 0; }
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;

    return [
      {'icon': '🌅', 'title': 'First Prayer', 'description': 'Complete your first prayer', 'unlocked': total > 0, 'rarity': 'Common', 'progress': total > 0 ? 1.0 : 0.0},
      {'icon': '⭐', 'title': 'Perfect Day', 'description': 'All 5 prayers in a day', 'unlocked': perfect > 0, 'rarity': 'Common', 'progress': perfect > 0 ? 1.0 : 0.0},
      {'icon': '🔥', 'title': 'Week Warrior', 'description': '7-day streak', 'unlocked': bestStreak >= 7, 'rarity': 'Uncommon', 'progress': (bestStreak / 7).clamp(0.0, 1.0)},
      {'icon': '📿', 'title': 'Centurion', 'description': '100 prayers completed', 'unlocked': total >= 100, 'rarity': 'Uncommon', 'progress': (total / 100).clamp(0.0, 1.0)},
      {'icon': '🌙', 'title': 'Month Master', 'description': '30-day streak', 'unlocked': bestStreak >= 30, 'rarity': 'Rare', 'progress': (bestStreak / 30).clamp(0.0, 1.0)},
      {'icon': '🏆', 'title': 'Perfectionist', 'description': '10 perfect days', 'unlocked': perfect >= 10, 'rarity': 'Rare', 'progress': (perfect / 10).clamp(0.0, 1.0)},
      {'icon': '🌟', 'title': 'Fajr Champion', 'description': 'Pray Fajr 30 times', 'unlocked': fajrCount >= 30, 'rarity': 'Rare', 'progress': (fajrCount / 30).clamp(0.0, 1.0)},
      {'icon': '👑', 'title': 'Prayer Master', 'description': '500 prayers completed', 'unlocked': total >= 500, 'rarity': 'Epic', 'progress': (total / 500).clamp(0.0, 1.0)},
      {'icon': '💎', 'title': 'Legendary', 'description': '100-day streak', 'unlocked': bestStreak >= 100, 'rarity': 'Legendary', 'progress': (bestStreak / 100).clamp(0.0, 1.0)},
    ];
  }
}
