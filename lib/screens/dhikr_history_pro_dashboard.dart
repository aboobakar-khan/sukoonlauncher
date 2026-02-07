import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/tasbih_provider.dart';
import '../providers/premium_provider.dart';
import 'premium_paywall_screen.dart';

/// Dhikr History Pro Dashboard - PREMIUM FEATURE
/// Clean 3-tab design: Journey · Adhkar · Badges
class DhikrHistoryProDashboard extends ConsumerStatefulWidget {
  const DhikrHistoryProDashboard({super.key});

  @override
  ConsumerState<DhikrHistoryProDashboard> createState() => _DhikrHistoryProDashboardState();
}

class _DhikrHistoryProDashboardState extends ConsumerState<DhikrHistoryProDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Camel brand palette + amber accent for dhikr
  static const Color _sand = Color(0xFFC2A366);
  static const Color _camel = Color(0xFFA67B5B);
  static const Color _amber = Color(0xFFFFCA28);
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

    final tasbihState = ref.watch(tasbihProvider);

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
                  _JourneyTab(state: tasbihState),
                  const _AdhkarTab(),
                  _BadgesTab(state: tasbihState),
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
                          color: _amber.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_outline, color: _amber, size: 40),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Unlock Dhikr Analytics',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your dhikr journey, earn badges,\nexplore morning & evening adhkar',
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
                Text('Dhikr Analytics', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                Text('Remember Allah always', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
          color: _amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        dividerColor: Colors.transparent,
        labelColor: _amber,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        tabs: const [
          Tab(text: 'Journey'),
          Tab(text: 'Adhkar'),
          Tab(text: 'Badges'),
        ],
      ),
    );
  }
}

// =============================================================================
// JOURNEY TAB - Stats, Progress, Wisdom combined
// =============================================================================
class _JourneyTab extends StatelessWidget {
  final TasbihState state;
  const _JourneyTab({required this.state});

  static const Color _amber = Color(0xFFFFCA28);
  static const Color _sand = Color(0xFFC2A366);
  static const Color _card = Color(0xFF111111);
  static const Color _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    final wisdomItems = _getWisdomItems();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Hero Stats ───
          _buildHeroStats(),
          const SizedBox(height: 16),

          // ─── Streak ───
          _buildStreakCard(),
          const SizedBox(height: 20),

          // ─── Weekly Progress ───
          _label('THIS WEEK'),
          const SizedBox(height: 10),
          _buildWeeklyStats(context),
          const SizedBox(height: 20),

          // ─── Dhikr Types ───
          if (state.dhikrCounts.isNotEmpty) ...[
            _label('DHIKR BREAKDOWN'),
            const SizedBox(height: 10),
            _buildDhikrBreakdown(),
            const SizedBox(height: 20),
          ],

          // ─── Daily Goal ───
          _buildDailyGoal(),
          const SizedBox(height: 16),

          // ─── Milestone ───
          _buildMilestone(),
          const SizedBox(height: 20),

          // ─── Wisdom (inline, not separate tab) ───
          _label('WISDOM'),
          const SizedBox(height: 10),
          ...wisdomItems.take(3).map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildWisdomCard(w),
          )),
        ],
      ),
    );
  }

  // ─── HERO STATS ───
  Widget _buildHeroStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_amber.withOpacity(0.12), _amber.withOpacity(0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _amber.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          // Main total
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📿', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtNum(state.totalAllTime),
                    style: const TextStyle(color: _amber, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  Text('Total Dhikr', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mini stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: _miniStat('📅', '${state.todayCount}', 'Today')),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.06)),
                Expanded(child: _miniStat('📊', '${state.monthlyTotal}', 'This Month')),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.06)),
                Expanded(child: _miniStat('🎯', '${state.completedTargets}', 'Goals Met')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
      ],
    );
  }

  // ─── STREAK ───
  Widget _buildStreakCard() {
    final streak = state.streakDays;
    final atRisk = state.todayCount == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: atRisk && streak > 0 ? Colors.orange.withOpacity(0.08) : _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: atRisk && streak > 0 ? Colors.orange.withOpacity(0.25) : Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Text(streak > 0 ? '🔥' : '❄️', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('$streak', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('day streak', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                ]),
                if (atRisk && streak > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('⚠️ Don\'t lose your streak! Count some dhikr 📿',
                      style: TextStyle(color: Colors.orange.shade300, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── WEEKLY STATS ───
  Widget _buildWeeklyStats(BuildContext context) {
    final today = DateTime.now();
    final startOfMonth = DateTime(today.year, today.month, 1);
    final daysInMonth = today.difference(startOfMonth).inDays + 1;
    final avgPerDay = daysInMonth > 0 ? (state.monthlyTotal / daysInMonth) : 0.0;
    final weeklyEst = (avgPerDay * 7).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(children: [
            // Today
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_amber.withOpacity(0.12), _amber.withOpacity(0.04)]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _amber.withOpacity(0.2)),
                ),
                child: Column(children: [
                  Text('${state.todayCount}', style: const TextStyle(color: _amber, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Today', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            // Weekly avg
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text('~$weeklyEst', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Weekly Avg', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            // Streak
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (state.streakDays > 0) const Text('🔥', style: TextStyle(fontSize: 10)),
                    Text('${state.streakDays}', style: TextStyle(
                      color: state.streakDays > 0 ? const Color(0xFFFF6B35) : Colors.white.withOpacity(0.4),
                      fontSize: 24, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 2),
                  Text('Streak', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                ]),
              ),
            ),
          ]),
          if (state.monthlyTotal > 0) ...[
            const SizedBox(height: 12),
            Text('Monthly: ${state.monthlyTotal} · Daily avg: ${avgPerDay.toStringAsFixed(1)}',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  // ─── DHIKR BREAKDOWN ───
  Widget _buildDhikrBreakdown() {
    const dhikrNames = [
      'SubhanAllah', 'Alhamdulillah', 'Allahu Akbar', 'La ilaha illallah',
      'Astaghfirullah', 'Astaghfirullah al-Azeem', 'SubhanAllahi wa bihamdihi',
      'SubhanAllah al-Azeem', 'Allahumma salli ala Muhammad',
      'La hawla wa la quwwata', 'Combined Tasbeeh',
    ];

    final sorted = state.dhikrCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = sorted.isNotEmpty ? sorted.first.value : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: sorted.take(6).map((e) {
          final name = e.key < dhikrNames.length ? dhikrNames[e.key] : 'Dhikr ${e.key}';
          final pct = maxCount > 0 ? e.value / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Text(name, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(_amber.withOpacity(0.4 + pct * 0.6)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${e.value}', textAlign: TextAlign.right,
                  style: TextStyle(color: _amber.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ─── DAILY GOAL ───
  Widget _buildDailyGoal() {
    final progress = state.targetCount > 0 ? (state.todayCount / state.targetCount).clamp(0.0, 1.0) : 0.0;
    final complete = state.todayCount >= state.targetCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: complete ? _sand.withOpacity(0.08) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: complete ? _sand.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Text(complete ? '✅' : '🎯', style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(complete ? 'Daily Goal Complete!' : 'Daily Goal',
                  style: TextStyle(color: complete ? _sand : Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(children: [
                  Text('${state.todayCount}', style: TextStyle(color: complete ? _sand : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(' / ${state.targetCount}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 22)),
                ]),
                if (!complete) Text('${state.targetCount - state.todayCount} more to go!',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            width: 52, height: 52,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: progress, strokeWidth: 5,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(complete ? _sand : _amber),
              ),
              Text('${(progress * 100).toInt()}%', style: TextStyle(
                color: complete ? _sand : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        ],
      ),
    );
  }

  // ─── MILESTONE ───
  Widget _buildMilestone() {
    final milestones = [100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000];
    final next = milestones.firstWhere((m) => m > state.totalAllTime, orElse: () => 1000000);
    final prev = milestones.lastWhere((m) => m <= state.totalAllTime, orElse: () => 0);
    final progress = (state.totalAllTime - prev) / (next - prev);
    final remaining = next - state.totalAllTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple.withOpacity(0.08), Colors.blue.withOpacity(0.04)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withOpacity(0.15)),
      ),
      child: Column(children: [
        Row(children: [
          const Text('🏅', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Milestone', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                Row(children: [
                  Text(_fmtNum(next), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(' Dhikr', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
                ]),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0), backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: const AlwaysStoppedAnimation(Colors.purple), minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(progress * 100).toInt()}%', style: TextStyle(color: Colors.purple.shade300, fontSize: 11)),
          Text('${_fmtNum(remaining)} to go', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
        ]),
      ]),
    );
  }

  // ─── WISDOM CARDS ───
  Widget _buildWisdomCard(Map<String, String> w) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w['icon']!, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w['title']!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(w['text']!, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.5)),
                if (w['source'] != null && w['source']!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(w['source']!, style: TextStyle(color: _gold.withOpacity(0.5), fontSize: 10)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getWisdomItems() {
    return [
      {'icon': '📿', 'title': 'SubhanAllah', 'text': '"SubhanAllah fills the scale of good deeds."', 'source': 'Sahih Muslim'},
      {'icon': '💎', 'title': 'Treasures of Jannah', 'text': '"La hawla wa la quwwata illa billah is a treasure from the treasures of Jannah."', 'source': 'Bukhari & Muslim'},
      {'icon': '🌳', 'title': 'Trees in Paradise', 'text': '"For every SubhanAllah a tree is planted for you in Paradise."', 'source': 'Tirmidhi'},
      {'icon': '⚖️', 'title': 'Heavy on the Scale', 'text': '"SubhanAllahi wa bihamdihi, SubhanAllah al-Azeem - light on the tongue, heavy on the scales."', 'source': 'Bukhari'},
      {'icon': '🤲', 'title': 'Best of Speech', 'text': '"The best of dhikr is La ilaha illallah."', 'source': 'Tirmidhi'},
      {'icon': '✨', 'title': 'Sins Forgiven', 'text': '"Whoever says SubhanAllahi wa bihamdihi 100 times, his sins are forgiven."', 'source': 'Bukhari'},
    ];
  }

  // ─── HELPERS ───
  Widget _label(String text) {
    return Text(text, style: TextStyle(
      color: Colors.white.withOpacity(0.35), fontSize: 12,
      fontWeight: FontWeight.w600, letterSpacing: 1.0,
    ));
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// =============================================================================
// ADHKAR TAB - Morning/Evening Adhkar, 99 Names, Prophetic Duas
// =============================================================================
class _AdhkarTab extends StatefulWidget {
  const _AdhkarTab();

  @override
  State<_AdhkarTab> createState() => _AdhkarTabState();
}

class _AdhkarTabState extends State<_AdhkarTab> {
  int _selectedSection = 0;
  Map<String, int> _adhkarProgress = {};
  int _namesLearned = 0;

  static const Color _amber = Color(0xFFFFCA28);
  static const Color _teal = Color(0xFF00897B);
  static const Color _purple = Color(0xFF9C27B0);
  static const Color _card = Color(0xFF111111);
  static const Color _morningColor = Color(0xFFFFB74D);
  static const Color _eveningColor = Color(0xFF7986CB);

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final box = await Hive.openBox('adhkar_data');
      final today = DateTime.now().toIso8601String().split('T')[0];
      final saved = box.get('adhkar_progress_$today');
      if (saved != null && saved is Map) {
        setState(() => _adhkarProgress = Map<String, int>.from(saved));
      }
      final names = box.get('names_learned');
      if (names != null) setState(() => _namesLearned = names as int);
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final box = await Hive.openBox('adhkar_data');
      final today = DateTime.now().toIso8601String().split('T')[0];
      await box.put('adhkar_progress_$today', _adhkarProgress);
      await box.put('names_learned', _namesLearned);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildSectionSelector(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildSectionContent(),
        ),
      ),
    ]);
  }

  Widget _buildSectionSelector() {
    final sections = [
      {'icon': '🌅', 'label': 'Morning', 'color': _morningColor},
      {'icon': '🌙', 'label': 'Evening', 'color': _eveningColor},
      {'icon': '✨', 'label': '99 Names', 'color': _amber},
      {'icon': '🤲', 'label': 'Duas', 'color': _teal},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: List.generate(sections.length, (i) {
          final s = sections[i];
          final sel = _selectedSection == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedSection = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? (s['color'] as Color).withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  Text(s['icon'] as String, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(s['label'] as String, style: TextStyle(
                    color: sel ? s['color'] as Color : Colors.white38,
                    fontSize: 10, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  )),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 0: return _buildAdhkarList(_getMorningAdhkar(), _morningColor, 'Morning Adhkar', 'أذكار الصباح', Icons.wb_sunny_outlined);
      case 1: return _buildAdhkarList(_getEveningAdhkar(), _eveningColor, 'Evening Adhkar', 'أذكار المساء', Icons.nightlight_outlined);
      case 2: return _build99Names();
      case 3: return _buildPropheticDuas();
      default: return _buildAdhkarList(_getMorningAdhkar(), _morningColor, 'Morning Adhkar', 'أذكار الصباح', Icons.wb_sunny_outlined);
    }
  }

  // ─── ADHKAR LIST ───
  Widget _buildAdhkarList(List<Map<String, dynamic>> adhkar, Color color, String title, String arabic, IconData icon) {
    final completed = adhkar.where((a) => (_adhkarProgress[a['key']] ?? 0) >= (a['count'] as int)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(0.12), color.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(arabic, style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('$completed/${adhkar.length}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        // List
        ...adhkar.map((dhikr) {
          final key = dhikr['key'] as String;
          final target = dhikr['count'] as int;
          final current = _adhkarProgress[key] ?? 0;
          final isDone = current >= target;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDone ? color.withOpacity(0.06) : _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDone ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Arabic
                Text(dhikr['arabic'] as String, style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontFamily: 'Amiri', height: 1.8)),
                const SizedBox(height: 8),
                // Translation
                Text(dhikr['translation'] as String, style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 10),
                // Counter
                Row(children: [
                  Text('$current / $target', style: TextStyle(
                    color: isDone ? color : Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (!isDone)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _adhkarProgress[key] = (current + 1).clamp(0, target));
                        _saveProgress();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Tap +1', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    Icon(Icons.check_circle, color: color, size: 20),
                ]),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─── 99 NAMES ───
  Widget _build99Names() {
    final names = _get99Names();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_amber.withOpacity(0.12), _amber.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Text('✨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Asma ul Husna', style: TextStyle(color: _amber, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('أسماء الله الحسنى', style: TextStyle(color: _amber.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            Text('$_namesLearned/${names.length}', style: TextStyle(color: _amber.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: names.asMap().entries.map((e) {
            final learned = e.key < _namesLearned;
            return GestureDetector(
              onTap: () {
                if (!learned && e.key <= _namesLearned) {
                  HapticFeedback.lightImpact();
                  setState(() => _namesLearned = e.key + 1);
                  _saveProgress();
                }
              },
              child: Container(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: learned ? _amber.withOpacity(0.08) : _card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: learned ? _amber.withOpacity(0.2) : Colors.white.withOpacity(0.04)),
                ),
                child: Column(children: [
                  Text(e.value['arabic']!, style: TextStyle(
                    color: learned ? _amber : Colors.white.withOpacity(0.5),
                    fontSize: 16, fontFamily: 'Amiri')),
                  const SizedBox(height: 2),
                  Text(e.value['english']!, style: TextStyle(
                    color: learned ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.3),
                    fontSize: 9), textAlign: TextAlign.center),
                ]),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── PROPHETIC DUAS ───
  Widget _buildPropheticDuas() {
    final duas = _getPropheticDuas();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_teal.withOpacity(0.12), _teal.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Text('🤲', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prophetic Duas', style: TextStyle(color: _teal, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Authentic supplications', style: TextStyle(color: _teal.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        ...duas.map((d) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d['arabic']!, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Amiri', height: 1.8)),
              const SizedBox(height: 8),
              Text(d['translation']!, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontStyle: FontStyle.italic, height: 1.5)),
              const SizedBox(height: 6),
              Text(d['source']!, style: TextStyle(color: _teal.withOpacity(0.5), fontSize: 10)),
            ],
          ),
        )),
      ],
    );
  }

  // ─── DATA ───
  List<Map<String, dynamic>> _getMorningAdhkar() {
    return [
      {'key': 'morning_ayatul_kursi', 'arabic': 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ', 'translation': 'Allah, there is no god but He, the Living, the Self-Subsisting', 'count': 1},
      {'key': 'morning_ikhlas', 'arabic': 'قُلْ هُوَ اللَّهُ أَحَدٌ', 'translation': 'Say: He is Allah, the One', 'count': 3},
      {'key': 'morning_falaq', 'arabic': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ', 'translation': 'Say: I seek refuge in the Lord of daybreak', 'count': 3},
      {'key': 'morning_naas', 'arabic': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ', 'translation': 'Say: I seek refuge in the Lord of mankind', 'count': 3},
      {'key': 'morning_master', 'arabic': 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ', 'translation': 'O Allah, You are my Lord, none has the right to be worshipped but You', 'count': 1},
      {'key': 'morning_subhanallah', 'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'translation': 'Glory and praise be to Allah', 'count': 100},
    ];
  }

  List<Map<String, dynamic>> _getEveningAdhkar() {
    return [
      {'key': 'evening_ayatul_kursi', 'arabic': 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ', 'translation': 'Allah, there is no god but He, the Living, the Self-Subsisting', 'count': 1},
      {'key': 'evening_ikhlas', 'arabic': 'قُلْ هُوَ اللَّهُ أَحَدٌ', 'translation': 'Say: He is Allah, the One', 'count': 3},
      {'key': 'evening_falaq', 'arabic': 'قُلْ أَعُوذُ بِرَبِّ الْفَلَقِ', 'translation': 'Say: I seek refuge in the Lord of daybreak', 'count': 3},
      {'key': 'evening_naas', 'arabic': 'قُلْ أَعُوذُ بِرَبِّ النَّاسِ', 'translation': 'Say: I seek refuge in the Lord of mankind', 'count': 3},
      {'key': 'evening_protection', 'arabic': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِن شَرِّ مَا خَلَقَ', 'translation': 'I seek refuge in the perfect words of Allah from the evil of what He created', 'count': 3},
      {'key': 'evening_subhanallah', 'arabic': 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'translation': 'Glory and praise be to Allah', 'count': 100},
    ];
  }

  List<Map<String, String>> _get99Names() {
    return [
      {'arabic': 'الرَّحْمَنُ', 'english': 'The Most Gracious'},
      {'arabic': 'الرَّحِيمُ', 'english': 'The Most Merciful'},
      {'arabic': 'الْمَلِكُ', 'english': 'The King'},
      {'arabic': 'الْقُدُّوسُ', 'english': 'The Most Holy'},
      {'arabic': 'السَّلَامُ', 'english': 'The Source of Peace'},
      {'arabic': 'الْمُؤْمِنُ', 'english': 'The Guardian of Faith'},
      {'arabic': 'الْمُهَيْمِنُ', 'english': 'The Protector'},
      {'arabic': 'الْعَزِيزُ', 'english': 'The Mighty'},
      {'arabic': 'الْجَبَّارُ', 'english': 'The Compeller'},
      {'arabic': 'الْمُتَكَبِّرُ', 'english': 'The Majestic'},
      {'arabic': 'الْخَالِقُ', 'english': 'The Creator'},
      {'arabic': 'الْبَارِئُ', 'english': 'The Evolver'},
      {'arabic': 'الْمُصَوِّرُ', 'english': 'The Fashioner'},
      {'arabic': 'الْغَفَّارُ', 'english': 'The Forgiver'},
      {'arabic': 'الْقَهَّارُ', 'english': 'The Subduer'},
      {'arabic': 'الْوَهَّابُ', 'english': 'The Bestower'},
      {'arabic': 'الرَّزَّاقُ', 'english': 'The Provider'},
      {'arabic': 'الْفَتَّاحُ', 'english': 'The Opener'},
      {'arabic': 'اَلْعَلِيْمُ', 'english': 'The All-Knowing'},
      {'arabic': 'الْقَابِضُ', 'english': 'The Constrictor'},
      {'arabic': 'الْبَاسِطُ', 'english': 'The Expander'},
      {'arabic': 'الْخَافِضُ', 'english': 'The Abaser'},
      {'arabic': 'الرَّافِعُ', 'english': 'The Exalter'},
      {'arabic': 'الْمُعِزُّ', 'english': 'The Honorer'},
      {'arabic': 'المُذِلُّ', 'english': 'The Humiliator'},
      {'arabic': 'السَّمِيعُ', 'english': 'The All-Hearing'},
      {'arabic': 'الْبَصِيرُ', 'english': 'The All-Seeing'},
      {'arabic': 'الْحَكَمُ', 'english': 'The Judge'},
      {'arabic': 'الْعَدْلُ', 'english': 'The Just'},
      {'arabic': 'اللَّطِيفُ', 'english': 'The Subtle One'},
    ];
  }

  List<Map<String, String>> _getPropheticDuas() {
    return [
      {'arabic': 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ', 'translation': 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.', 'source': 'Al-Baqarah 2:201'},
      {'arabic': 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ', 'translation': 'O Allah, I seek refuge in You from worry and grief.', 'source': 'Bukhari'},
      {'arabic': 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي', 'translation': 'My Lord, expand for me my chest and ease for me my task.', 'source': 'Ta-Ha 20:25-26'},
      {'arabic': 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ', 'translation': 'O Allah, help me to remember You, thank You, and worship You well.', 'source': 'Abu Dawud'},
      {'arabic': 'رَبَّنَا لَا تُزِغْ قُلُوبَنَا بَعْدَ إِذْ هَدَيْتَنَا', 'translation': 'Our Lord, do not let our hearts deviate after You have guided us.', 'source': 'Aal Imran 3:8'},
    ];
  }
}

// =============================================================================
// BADGES TAB
// =============================================================================
class _BadgesTab extends StatelessWidget {
  final TasbihState state;
  const _BadgesTab({required this.state});

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
                Text('Keep remembering Allah to unlock more!', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
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
    final total = state.totalAllTime;
    final streak = state.streakDays;

    return [
      {'icon': '🌱', 'title': 'First Step', 'description': 'Complete your first dhikr', 'unlocked': total > 0, 'rarity': 'Common', 'progress': total > 0 ? 1.0 : 0.0},
      {'icon': '💯', 'title': 'Century Club', 'description': '100 total dhikr', 'unlocked': total >= 100, 'rarity': 'Common', 'progress': (total / 100).clamp(0.0, 1.0)},
      {'icon': '🔥', 'title': 'Week Warrior', 'description': '7-day streak', 'unlocked': streak >= 7, 'rarity': 'Uncommon', 'progress': (streak / 7).clamp(0.0, 1.0)},
      {'icon': '🎯', 'title': 'Goal Getter', 'description': 'Complete daily target 10 times', 'unlocked': state.completedTargets >= 10, 'rarity': 'Uncommon', 'progress': (state.completedTargets / 10).clamp(0.0, 1.0)},
      {'icon': '📿', 'title': 'Devoted', 'description': '1,000 total dhikr', 'unlocked': total >= 1000, 'rarity': 'Rare', 'progress': (total / 1000).clamp(0.0, 1.0)},
      {'icon': '🌙', 'title': 'Month Master', 'description': '30-day streak', 'unlocked': streak >= 30, 'rarity': 'Rare', 'progress': (streak / 30).clamp(0.0, 1.0)},
      {'icon': '⭐', 'title': 'Rising Star', 'description': '10,000 total dhikr', 'unlocked': total >= 10000, 'rarity': 'Epic', 'progress': (total / 10000).clamp(0.0, 1.0)},
      {'icon': '👑', 'title': 'Dhikr Master', 'description': '100,000 total dhikr', 'unlocked': total >= 100000, 'rarity': 'Legendary', 'progress': (total / 100000).clamp(0.0, 1.0)},
    ];
  }
}
