import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/prayer_provider.dart';
import '../providers/premium_provider.dart';
import '../models/prayer_record.dart';
import 'premium_paywall_screen.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Prayer Analytics Dashboard - Redesigned for minimalism & professional UX
class PrayerHistoryDashboard extends ConsumerStatefulWidget {
  const PrayerHistoryDashboard({super.key});

  @override
  ConsumerState<PrayerHistoryDashboard> createState() => _PrayerHistoryDashboardState();
}

class _PrayerHistoryDashboardState extends ConsumerState<PrayerHistoryDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Minimalist color palette - gold accent only
  static const _gold = Color(0xFFC2A366);
  static const _bg = Color(0xFF000000);
  static const _cardBg = Color(0xFF0D0D0D);

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

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(recordsMap: recordsMap, records: records),
                  _CalendarTab(
                    recordsMap: recordsMap,
                    selectedYear: _selectedYear,
                    selectedMonth: _selectedMonth,
                    onMonthChanged: (y, m) => setState(() {
                      _selectedYear = y;
                      _selectedMonth = m;
                    }),
                  ),
                  _AchievementsTab(recordsMap: recordsMap),
                ],
              ),
            ),
          ],
        ),
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
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_outline, color: _gold, size: 36),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Prayer Analytics',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your spiritual journey with detailed\ninsights and progress metrics',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14, height: 1.6),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumPaywallScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Upgrade to Premium', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 15)),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prayer Analytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Your spiritual journey', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, color: _gold, size: 14),
                const SizedBox(width: 4),
                Text('PRO', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: _gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        dividerColor: Colors.transparent,
        labelColor: _gold,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Calendar'),
          Tab(text: 'Achievements'),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB - Stats, streaks, insights
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;
  final List<PrayerRecord> records;
  
  const _OverviewTab({required this.recordsMap, required this.records});

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildMetricsGrid(stats),
        const SizedBox(height: 16),
        _buildStreakCard(stats),
        const SizedBox(height: 24),
        _buildSectionLabel('Weekly Consistency'),
        const SizedBox(height: 12),
        _buildWeeklyChart(stats),
        const SizedBox(height: 24),
        _buildSectionLabel('Prayer Breakdown'),
        const SizedBox(height: 12),
        _buildPrayerBreakdown(stats),
        const SizedBox(height: 24),
        _buildSectionLabel('Daily Namaz History'),
        const SizedBox(height: 12),
        _buildNamazHistory(),
      ],
    );
  }

  Map<String, dynamic> _calculateStats() {
    int currentStreak = 0, bestStreak = 0, tempStreak = 0;
    int totalPrayers = 0, perfectDays = 0;
    bool streakAtRisk = false;
    final prayerCounts = {'Fajr': 0, 'Dhuhr': 0, 'Asr': 0, 'Maghrib': 0, 'Isha': 0};

    final sorted = recordsMap.keys.toList()..sort();
    for (int i = sorted.length - 1; i >= 0; i--) {
      final r = recordsMap[sorted[i]];
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

    final todayKey = _formatDate(DateTime.now());
    final todayRec = recordsMap[todayKey];
    streakAtRisk = currentStreak > 0 && (todayRec == null || todayRec.completedCount < 3);

    return {
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalPrayers': totalPrayers,
      'perfectDays': perfectDays,
      'totalDays': recordsMap.length,
      'avgPerDay': recordsMap.isEmpty ? 0.0 : totalPrayers / recordsMap.length,
      'consistency': recordsMap.isEmpty ? 0.0 : (perfectDays / recordsMap.length * 100),
      'streakAtRisk': streakAtRisk,
      'prayerCounts': prayerCounts,
    };
  }

  Widget _buildMetricsGrid(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetric('${stats['totalPrayers']}', 'Total Prayers'),
              const SizedBox(width: 16),
              _buildMetric('${stats['perfectDays']}', 'Perfect Days'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.04),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetric((stats['avgPerDay'] as double).toStringAsFixed(1), 'Daily Average'),
              const SizedBox(width: 16),
              _buildMetric('${(stats['consistency'] as double).toStringAsFixed(0)}%', 'Consistency'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _gold,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(Map<String, dynamic> stats) {
    final streak = stats['currentStreak'] as int;
    final best = stats['bestStreak'] as int;
    final atRisk = stats['streakAtRisk'] as bool;
    final isRecord = streak >= best && streak > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: atRisk ? const Color(0xFFFF6B35).withValues(alpha: 0.06) : _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: atRisk 
              ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
              : isRecord 
                  ? _gold.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: streak > 0 
                  ? (atRisk ? const Color(0xFFFF6B35) : _gold).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                streak > 0 ? '🔥' : '⭐',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$streak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'day streak',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                    if (isRecord) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'RECORD',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (atRisk) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Don\'t lose your streak! Pray now',
                    style: TextStyle(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                ] else if (!isRecord && best > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Best: $best days',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(Map<String, dynamic> stats) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key = _formatDate(d);
      return recordsMap[key]?.completedCount ?? 0;
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final count = days[i];
          final isToday = i == 6;
          final height = 6.0 + (count / 5 * 60);
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      color: count == 5 ? _gold : Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: count > 0 
                          ? _gold.withValues(alpha: 0.3 + (count / 5 * 0.7))
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weekDays[i],
                    style: TextStyle(
                      color: isToday ? _gold : Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPrayerBreakdown(Map<String, dynamic> stats) {
    final counts = stats['prayerCounts'] as Map<String, int>;
    final total = recordsMap.length;
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: prayers.asMap().entries.map((entry) {
          final i = entry.key;
          final prayer = entry.value;
          final count = counts[prayer] ?? 0;
          final pct = total > 0 ? (count / total) : 0.0;
          
          return Padding(
            padding: EdgeInsets.only(bottom: i < prayers.length - 1 ? 14 : 0),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    prayer,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      valueColor: AlwaysStoppedAnimation(
                        _gold.withValues(alpha: 0.3 + (pct * 0.7)),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: pct >= 0.8 
                          ? _gold 
                          : pct >= 0.5 
                              ? Colors.orange 
                              : const Color(0xFFFF6B35),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNamazHistory() {
    final now = DateTime.now();
    // Show last 7 days
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: i));
      final key = _formatDate(d);
      return {
        'date': d,
        'record': recordsMap[key],
      };
    });

    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerIcons = [
      Icons.wb_twilight_rounded,
      Icons.wb_sunny_rounded,
      Icons.wb_sunny_outlined,
      Icons.nights_stay_outlined,
      Icons.dark_mode_rounded,
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: days.asMap().entries.map((entry) {
          final i = entry.key;
          final date = entry.value['date'] as DateTime;
          final record = entry.value['record'] as PrayerRecord?;
          final isLast = i == days.length - 1;
          final isToday = i == 0;
          final isYesterday = i == 1;
          final completed = record?.completedCount ?? 0;
          final prayed = [
            record?.fajr ?? false,
            record?.dhuhr ?? false,
            record?.asr ?? false,
            record?.maghrib ?? false,
            record?.isha ?? false,
          ];

          String dayLabel;
          if (isToday) {
            dayLabel = 'Today';
          } else if (isYesterday) {
            dayLabel = 'Yesterday';
          } else {
            final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            dayLabel = '${weekDays[date.weekday - 1]}, ${date.day} ${_monthAbbr(date.month)}';
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isToday ? _gold.withValues(alpha: 0.03) : null,
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day label + count badge
                Row(
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        color: isToday ? _gold : Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: completed == 5
                            ? _gold.withValues(alpha: 0.15)
                            : completed > 0
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        completed == 5 ? '✓ All' : '$completed/5',
                        style: TextStyle(
                          color: completed == 5
                              ? _gold
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 5 prayer status pills
                Row(
                  children: List.generate(5, (pi) {
                    final done = prayed[pi];
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: pi < 4 ? 6 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: done
                              ? _gold.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: done
                                ? _gold.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              done ? Icons.check_rounded : prayerIcons[pi],
                              size: 14,
                              color: done
                                  ? _gold
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              prayerNames[pi],
                              style: TextStyle(
                                fontSize: 9,
                                color: done
                                    ? _gold.withValues(alpha: 0.8)
                                    : Colors.white.withValues(alpha: 0.25),
                                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  
  String _monthAbbr(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALENDAR TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _CalendarTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;
  final int selectedYear;
  final int selectedMonth;
  final Function(int, int) onMonthChanged;

  const _CalendarTab({
    required this.recordsMap,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildMonthSelector(),
        const SizedBox(height: 16),
        _buildHeatMap(),
        const SizedBox(height: 16),
        _buildMonthStats(),
      ],
    );
  }

  Widget _buildMonthSelector() {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onMonthChanged(
                selectedMonth == 1 ? selectedYear - 1 : selectedYear,
                selectedMonth == 1 ? 12 : selectedMonth - 1,
              );
            },
            child: Icon(
              Icons.chevron_left_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 24,
            ),
          ),
          Column(
            children: [
              Text(
                months[selectedMonth - 1],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$selectedYear',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final now = DateTime.now();
              if (selectedYear < now.year || (selectedYear == now.year && selectedMonth < now.month)) {
                onMonthChanged(
                  selectedMonth == 12 ? selectedYear + 1 : selectedYear,
                  selectedMonth == 12 ? 1 : selectedMonth + 1,
                );
              }
            },
            child: Icon(
              Icons.chevron_right_rounded,
              color: (selectedYear < DateTime.now().year || 
                      (selectedYear == DateTime.now().year && selectedMonth < DateTime.now().month))
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
              size: 24,
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          ...List.generate((daysInMonth + startWD - 1) ~/ 7 + 1, (week) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: List.generate(7, (di) {
                  final dayNum = week * 7 + di + 2 - startWD;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return Expanded(child: Container());
                  }
                  
                  final key = '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                  final count = recordsMap[key]?.completedCount ?? 0;
                  final isToday = selectedYear == DateTime.now().year && 
                                  selectedMonth == DateTime.now().month && 
                                  dayNum == DateTime.now().day;
                  
                  return Expanded(
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _heatColor(count),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday 
                            ? Border.all(color: Colors.white, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            color: count >= 3 
                                ? Colors.white 
                                : Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(Colors.white.withValues(alpha: 0.04), '0'),
              _legendItem(_gold.withValues(alpha: 0.2), '1-2'),
              _legendItem(_gold.withValues(alpha: 0.5), '3-4'),
              _legendItem(_gold, '5'),
            ],
          ),
        ],
      ),
    );
  }

  Color _heatColor(int count) {
    if (count == 0) return Colors.white.withValues(alpha: 0.04);
    if (count <= 2) return _gold.withValues(alpha: 0.2);
    if (count <= 4) return _gold.withValues(alpha: 0.5);
    return _gold;
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthStats() {
    int totalPrayers = 0, perfectDays = 0, trackedDays = 0;
    
    recordsMap.forEach((key, r) {
      if (key.startsWith('$selectedYear-${selectedMonth.toString().padLeft(2, '0')}')) {
        totalPrayers += r.completedCount;
        if (r.completedCount == 5) perfectDays++;
        trackedDays++;
      }
    });
    
    final avg = trackedDays > 0 ? totalPrayers / trackedDays : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          _buildStatItem('$totalPrayers', 'Total Prayers'),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          _buildStatItem('$perfectDays', 'Perfect Days'),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          _buildStatItem(avg.toStringAsFixed(1), 'Daily Avg'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _gold,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACHIEVEMENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _AchievementsTab extends StatelessWidget {
  final Map<String, PrayerRecord> recordsMap;

  const _AchievementsTab({required this.recordsMap});

  static const _gold = Color(0xFFC2A366);
  static const _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    final achievements = _calculateAchievements();
    final unlocked = achievements.where((a) => a['unlocked'] as bool).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: _gold,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$unlocked of ${achievements.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Achievements unlocked',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: unlocked / achievements.length,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: const AlwaysStoppedAnimation(_gold),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...achievements.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildAchievementCard(a),
        )),
      ],
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final unlocked = achievement['unlocked'] as bool;
    final progress = achievement['progress'] as double;
    final tier = achievement['tier'] as String;
    final tierColor = _getTierColor(tier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked 
            ? tierColor.withValues(alpha: 0.06)
            : _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked 
              ? tierColor.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked 
                  ? tierColor.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                achievement['icon'] as String,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      achievement['title'] as String,
                      style: TextStyle(
                        color: unlocked 
                            ? Colors.white 
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tierColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tier,
                        style: TextStyle(
                          color: tierColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement['description'] as String,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
                if (!unlocked && progress > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation(
                              tierColor.withValues(alpha: 0.5),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          unlocked
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: tierColor,
                    size: 16,
                  ),
                )
              : Icon(
                  Icons.lock_outline,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 20,
                ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'Bronze':
        return const Color(0xFFCD7F32);
      case 'Silver':
        return const Color(0xFFC0C0C0);
      case 'Gold':
        return const Color(0xFFFFD700);
      case 'Platinum':
        return const Color(0xFFE5E4E2);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _calculateAchievements() {
    int totalPrayers = 0, perfectDays = 0, bestStreak = 0, tempStreak = 0, fajrCount = 0;
    
    for (final r in recordsMap.values) {
      totalPrayers += r.completedCount;
      if (r.completedCount == 5) perfectDays++;
      if (r.fajr) fajrCount++;
      
      if (r.completedCount >= 3) {
        tempStreak++;
      } else {
        if (tempStreak > bestStreak) bestStreak = tempStreak;
        tempStreak = 0;
      }
    }
    if (tempStreak > bestStreak) bestStreak = tempStreak;

    return [
      {
        'icon': '🌅',
        'title': 'First Steps',
        'description': 'Complete your first prayer',
        'unlocked': totalPrayers > 0,
        'tier': 'Bronze',
        'progress': totalPrayers > 0 ? 1.0 : 0.0,
      },
      {
        'icon': '⭐',
        'title': 'Perfect Day',
        'description': 'Complete all 5 prayers in a day',
        'unlocked': perfectDays > 0,
        'tier': 'Bronze',
        'progress': perfectDays > 0 ? 1.0 : 0.0,
      },
      {
        'icon': '🔥',
        'title': 'Week Warrior',
        'description': 'Maintain a 7-day streak',
        'unlocked': bestStreak >= 7,
        'tier': 'Silver',
        'progress': (bestStreak / 7).clamp(0.0, 1.0),
      },
      {
        'icon': '📿',
        'title': 'Centurion',
        'description': 'Complete 100 prayers',
        'unlocked': totalPrayers >= 100,
        'tier': 'Silver',
        'progress': (totalPrayers / 100).clamp(0.0, 1.0),
      },
      {
        'icon': '🌙',
        'title': 'Month Master',
        'description': 'Maintain a 30-day streak',
        'unlocked': bestStreak >= 30,
        'tier': 'Gold',
        'progress': (bestStreak / 30).clamp(0.0, 1.0),
      },
      {
        'icon': '🏆',
        'title': 'Perfectionist',
        'description': 'Achieve 10 perfect days',
        'unlocked': perfectDays >= 10,
        'tier': 'Gold',
        'progress': (perfectDays / 10).clamp(0.0, 1.0),
      },
      {
        'icon': '🌟',
        'title': 'Fajr Champion',
        'description': 'Pray Fajr 30 times',
        'unlocked': fajrCount >= 30,
        'tier': 'Gold',
        'progress': (fajrCount / 30).clamp(0.0, 1.0),
      },
      {
        'icon': '👑',
        'title': 'Prayer Master',
        'description': 'Complete 500 prayers',
        'unlocked': totalPrayers >= 500,
        'tier': 'Platinum',
        'progress': (totalPrayers / 500).clamp(0.0, 1.0),
      },
      {
        'icon': '💎',
        'title': 'Legendary',
        'description': 'Maintain a 100-day streak',
        'unlocked': bestStreak >= 100,
        'tier': 'Platinum',
        'progress': (bestStreak / 100).clamp(0.0, 1.0),
      },
    ];
  }
}
