import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ramadan_provider.dart';
import '../providers/prayer_provider.dart';
import '../providers/sukoon_coin_provider.dart';
import '../models/prayer_record.dart';
import '../features/quran/screens/surah_list_screen.dart';

/// 🌙 Ramadan Dashboard — Immersive Redesign
/// Night sky atmosphere with live countdown, daily duas,
/// grouped ibadah checklist, Juz grid, and Last 10 Nights mode.

class RamadanDashboardScreen extends ConsumerStatefulWidget {
  const RamadanDashboardScreen({super.key});

  @override
  ConsumerState<RamadanDashboardScreen> createState() =>
      _RamadanDashboardScreenState();
}

class _RamadanDashboardScreenState
    extends ConsumerState<RamadanDashboardScreen>
    with TickerProviderStateMixin {
  Timer? _countdownTimer;
  late AnimationController _starController;
  late AnimationController _pulseController;

  // ── Palette ──
  static const _deepNavy = Color(0xFF0D1B2A);
  static const _cardBg = Color(0xFF111827);
  static const _moonGold = Color(0xFFC9A84C);
  static const _starGold = Color(0xFFFFD700);
  static const _emerald = Color(0xFF10B981);
  static const _last10Purple = Color(0xFF8B5CF6);
  static const _warmCream = Color(0xFFF5E6C8);
  static const _fastOrange = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _starController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ramadan = ref.watch(ramadanProvider);
    final todayPrayer = ref.watch(todayPrayerRecordProvider);
    final isLast10 = ramadan.isLast10Nights;
    final accent = isLast10 ? _last10Purple : _moonGold;

    return Stack(
      children: [
        // ── Background: Deep navy + starfield ──
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLast10
                  ? [
                      const Color(0xFF1A0A2E),
                      const Color(0xFF0D1B2A),
                      const Color(0xFF060613),
                    ]
                  : [
                      const Color(0xFF0D1B2A),
                      const Color(0xFF0A1628),
                      const Color(0xFF060613),
                    ],
            ),
          ),
        ),

        // ── Animated starfield ──
        AnimatedBuilder(
          animation: _starController,
          builder: (_, __) => CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _StarfieldPainter(
              animValue: _starController.value,
              isLast10: isLast10,
            ),
          ),
        ),

        // ── Content ──
        SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Live Countdown Header ───
              SliverToBoxAdapter(
                child: _buildLiveHeader(ramadan, accent),
              ),

              // ─── Suhoor / Iftar Context Card ───
              SliverToBoxAdapter(
                child: _buildSuhoorIftarCard(ramadan, accent),
              ),

              // ─── Daily Ramadan Dua ───
              SliverToBoxAdapter(
                child: _buildDailyDuaCard(ramadan, accent),
              ),

              // ─── Today's Ibadah Checklist ───
              SliverToBoxAdapter(
                child: _buildIbadahChecklist(ramadan, todayPrayer, ref, accent),
              ),

              // ─── Quran Khatm with Juz Grid ───
              SliverToBoxAdapter(
                child: _buildQuranKhatmCard(ramadan, accent, ref),
              ),

              // ─── Charity Tracker ───
              SliverToBoxAdapter(
                child: _buildCharityCard(ramadan, ref, accent),
              ),

              // ─── 30 Day Journey Progress ───
              SliverToBoxAdapter(
                child: _buildJourneyProgress(ramadan, accent),
              ),

              // ─── Last 10 Nights (if applicable) ───
              if (isLast10)
                SliverToBoxAdapter(
                  child: _buildLast10NightsCard(ramadan),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌙 LIVE COUNTDOWN HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLiveHeader(RamadanState r, Color accent) {
    final isFasting = r.isFastingTime;
    final countdown = isFasting ? r.timeUntilIftar : r.timeUntilSuhoor;
    final h = countdown.inHours;
    final m = countdown.inMinutes % 60;
    final s = countdown.inSeconds % 60;
    final label = isFasting ? 'until Iftar' : 'until Suhoor';
    final fastHours = r.fastDuration.inHours;
    final fastMins = r.fastDuration.inMinutes % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          // Crescent + Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('☪',
                  style: TextStyle(
                      fontSize: 14,
                      color: accent.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              Text(
                'RAMADAN',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Circular countdown ring
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Bg ring
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                // Progress ring (fasting progress)
                if (isFasting)
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: r.fastingProgress,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        _fastOrange.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time
                    Text(
                      '${h}h ${m}m',
                      style: TextStyle(
                        color: _warmCream.withValues(alpha: 0.95),
                        fontSize: 36,
                        fontWeight: FontWeight.w200,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isFasting) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _fastOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Fasting · ${fastHours}h ${fastMins}m',
                          style: TextStyle(
                            color: _fastOrange.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Day + Progress
          Text(
            'Day ${r.currentDay} of ${r.totalDays}',
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${r.daysRemaining} days remaining',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: r.overallProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(r.overallProgress * 100).toInt()}% Complete',
            style: TextStyle(
              color: accent.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🍽️ SUHOOR / IFTAR CONTEXTUAL CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSuhoorIftarCard(RamadanState r, Color accent) {
    final isFasting = r.isFastingTime;
    final nearIftar = r.timeUntilIftar.inMinutes <= 30 && isFasting;

    // Show iftar dua prominently near iftar time
    if (nearIftar) {
      return _glassCard(
        accent: _fastOrange,
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _fastOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('🌅', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Text(
                  'Iftar Time Approaching',
                  style: TextStyle(
                    color: _fastOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Dua in Arabic
            Text(
              RamadanState.iftarDuaArabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _warmCream.withValues(alpha: 0.95),
                fontSize: 20,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              RamadanState.iftarDuaTranslation,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // During non-fasting: Suhoor reminder
    if (!isFasting) {
      final suhoorTime = r.timeUntilSuhoor;
      final sH = suhoorTime.inHours;
      final sM = suhoorTime.inMinutes % 60;

      return _glassCard(
        accent: accent,
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('🌙', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suhoor in ${sH}h ${sM}m',
                    style: TextStyle(
                      color: _warmCream.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Eat well, rest well — tomorrow\'s fast awaits',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // During fasting — minimal
    return const SizedBox.shrink();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📿 DAILY RAMADAN DUA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDailyDuaCard(RamadanState r, Color accent) {
    return _glassCard(
      accent: accent,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accent, size: 15),
              const SizedBox(width: 8),
              Text(
                r.dailyDuaDay,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Clipboard.setData(ClipboardData(
                    text: '${r.dailyDuaArabic}\n\n${r.dailyDuaTranslation}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Dua copied'),
                      backgroundColor: accent.withValues(alpha: 0.8),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Icon(Icons.copy_rounded,
                    size: 14, color: accent.withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Arabic dua
          Text(
            r.dailyDuaArabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: _warmCream.withValues(alpha: 0.95),
              fontSize: 20,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          // Translation
          Text(
            r.dailyDuaTranslation,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          // Hadith secondary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded,
                    size: 14, color: accent.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.dailyHadith,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ TODAY'S IBADAH CHECKLIST (Grouped)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildIbadahChecklist(
    RamadanState r,
    PrayerRecord? prayer,
    WidgetRef ref,
    Color accent,
  ) {
    final prayerCount = prayer?.completedCount ?? 0;
    final totalCompleted = r.checklistCompleted + prayerCount;
    final totalItems = r.checklistTotal + 5;

    return _glassCard(
      accent: accent,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.task_alt_rounded, color: accent, size: 17),
              const SizedBox(width: 8),
              Text(
                'Today\'s Ibadah',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalCompleted/$totalItems',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Salah Group ──
          _groupLabel('🕌  Salah'),
          const SizedBox(height: 8),
          _checkRow('Fajr', prayer?.fajr ?? false, accent, onTap: () {
            ref
                .read(prayerRecordListProvider.notifier)
                .togglePrayer(DateTime.now(), 'fajr');
          }),
          _checkRow('Dhuhr', prayer?.dhuhr ?? false, accent, onTap: () {
            ref
                .read(prayerRecordListProvider.notifier)
                .togglePrayer(DateTime.now(), 'dhuhr');
          }),
          _checkRow('Asr', prayer?.asr ?? false, accent, onTap: () {
            ref
                .read(prayerRecordListProvider.notifier)
                .togglePrayer(DateTime.now(), 'asr');
          }),
          _checkRow('Maghrib', prayer?.maghrib ?? false, accent, onTap: () {
            ref
                .read(prayerRecordListProvider.notifier)
                .togglePrayer(DateTime.now(), 'maghrib');
          }),
          _checkRow('Isha', prayer?.isha ?? false, accent, onTap: () {
            ref
                .read(prayerRecordListProvider.notifier)
                .togglePrayer(DateTime.now(), 'isha');
          }),

          _divider(),

          // ── Ramadan Essentials ──
          _groupLabel('🌙  Ramadan Essentials'),
          const SizedBox(height: 8),
          _checkRow('Suhoor', r.suhoorDone, accent, onTap: () {
            ref.read(ramadanProvider.notifier).toggleSuhoor();
          }),
          _checkRow('Iftar Dua', r.iftarDuaDone, accent, onTap: () {
            ref.read(ramadanProvider.notifier).toggleIftarDua();
          }),

          // Taraweeh with rakat selector
          _buildTaraweehRow(r, ref, accent),

          _divider(),

          // ── Quran & Charity ──
          _groupLabel('📖  Growth'),
          const SizedBox(height: 8),
          _checkRow(
            'Quran Goal (${r.quranPagesReadToday}/${r.dailyQuranGoal} pages)',
            r.quranPagesReadToday >= r.dailyQuranGoal,
            accent,
          ),
          _checkRow('Daily Charity', r.charityDone, accent, onTap: () {
            ref.read(ramadanProvider.notifier).toggleCharity();
          }),
        ],
      ),
    );
  }

  Widget _buildTaraweehRow(RamadanState r, WidgetRef ref, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: r.taraweehDone
            ? accent.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: r.taraweehDone
              ? accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          _checkCircle(r.taraweehDone, accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Taraweeh${r.taraweehRakats > 0 ? ' · ${r.taraweehRakats} rakats' : ''}',
              style: TextStyle(
                color: r.taraweehDone
                    ? _warmCream.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: r.taraweehDone ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          // Rakat quick select
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [8, 20].map((rakats) {
              final isSelected = r.taraweehRakats == rakats;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(ramadanProvider.notifier)
                      .setTaraweehRakats(isSelected ? 0 : rakats);
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? accent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    '$rakats',
                    style: TextStyle(
                      color: isSelected
                          ? accent
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📖 QURAN KHATM WITH JUZ GRID
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuranKhatmCard(RamadanState r, Color accent, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SurahListScreen()),
        );
      },
      child: _glassCard(
        accent: _emerald,
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: _emerald, size: 17),
                const SizedBox(width: 8),
                Text(
                  'Quran Khatm',
                  style: TextStyle(
                    color: _emerald.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.quranPaceStatus,
                    style: TextStyle(
                      color: _emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Juz + Pages
            Row(
              children: [
                Text(
                  'Juz ${r.quranJuz}',
                  style: TextStyle(
                    color: _warmCream.withValues(alpha: 0.95),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ' of 30',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${r.quranTotalPagesRead}/604',
                  style: TextStyle(
                    color: _emerald.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 30 Juz visual grid
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List.generate(30, (i) {
                final completed = i < r.quranJuz;
                final current = i == r.quranJuz;
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: completed
                        ? _emerald.withValues(alpha: 0.25)
                        : current
                            ? _emerald.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.03),
                    border: Border.all(
                      color: current
                          ? _emerald.withValues(alpha: 0.5)
                          : completed
                              ? _emerald.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                      width: current ? 1.5 : 1,
                    ),
                  ),
                  child: Center(
                    child: completed
                        ? Icon(Icons.check_rounded,
                            size: 14,
                            color: _emerald.withValues(alpha: 0.8))
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: current
                                  ? _emerald.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.2),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 14),

            // Today's goal + add button
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _emerald.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _emerald.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.today_outlined,
                      size: 14, color: _emerald.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Text(
                    'Today: ${r.quranPagesReadToday}/${r.adjustedDailyGoal} pages',
                    style: TextStyle(
                      color: _warmCream.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showQuranPagesDialog(ref, r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+ Log',
                        style: TextStyle(
                          color: _emerald,
                          fontSize: 11,
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

  void _showQuranPagesDialog(WidgetRef ref, RamadanState r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Pages',
            style: TextStyle(color: _warmCream, fontSize: 16)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [1, 2, 5, 10, 20].map((p) {
            return ElevatedButton(
              onPressed: () {
                ref.read(ramadanProvider.notifier).addQuranPages(p);
                ref.read(sukoonCoinProvider.notifier).awardQuranReading();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald.withValues(alpha: 0.2),
                foregroundColor: _emerald,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('+$p'),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💰 CHARITY TRACKER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCharityCard(RamadanState r, WidgetRef ref, Color accent) {
    return _glassCard(
      accent: accent,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism, color: accent, size: 17),
              const SizedBox(width: 8),
              Text(
                'Charity This Ramadan',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${r.totalCharityAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  color: _warmCream.withValues(alpha: 0.95),
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'donated',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (r.charityGoal > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: (r.totalCharityAmount / r.charityGoal).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Goal: \$${r.charityGoal.toStringAsFixed(0)}',
              style: TextStyle(
                color: accent.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _showCharityDialog(ref),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      'Log Charity',
                      style: TextStyle(
                        color: accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCharityDialog(WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Charity', style: TextStyle(color: _warmCream)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: _warmCream, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter amount',
            prefixText: '\$ ',
            prefixStyle: TextStyle(color: _moonGold, fontSize: 16),
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide:
                  BorderSide(color: _moonGold.withValues(alpha: 0.3)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _moonGold),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount > 0) {
                ref.read(ramadanProvider.notifier).addCharity(amount);
                ref.read(sukoonCoinProvider.notifier).awardDailyChallenge();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _moonGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📅 30-DAY JOURNEY PROGRESS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildJourneyProgress(RamadanState r, Color accent) {
    return _glassCard(
      accent: accent,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: accent, size: 17),
              const SizedBox(width: 8),
              Text(
                'Ramadan Journey',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (r.currentStreak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        '${r.currentStreak} streak',
                        style: TextStyle(
                          color: _emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 30-day grid (5 rows × 6 cols)
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: List.generate(r.totalDays, (i) {
              final day = i + 1;
              final date = r.ramadanStartDate.add(Duration(days: i));
              final dateKey =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final isPerfect = r.completedDays.contains(dateKey);
              final isCurrent = day == r.currentDay;
              final isFuture = day > r.currentDay;
              final isOddNight =
                  r.isLast10Nights && day > (r.totalDays - 10) && day.isOdd;

              return AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final glow = isCurrent ? _pulseController.value * 0.3 : 0.0;
                  return Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isPerfect
                          ? _emerald.withValues(alpha: 0.3)
                          : isCurrent
                              ? accent.withValues(alpha: 0.15 + glow)
                              : isFuture
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: isCurrent
                            ? accent.withValues(alpha: 0.6)
                            : isOddNight
                                ? _last10Purple.withValues(alpha: 0.3)
                                : isPerfect
                                    ? _emerald.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                        width: isCurrent ? 1.5 : 1,
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.15 + glow),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isPerfect
                          ? Icon(Icons.check_rounded,
                              size: 14,
                              color: _emerald.withValues(alpha: 0.9))
                          : Text(
                              '$day',
                              style: TextStyle(
                                color: isCurrent
                                    ? accent
                                    : isFuture
                                        ? Colors.white
                                            .withValues(alpha: 0.15)
                                        : Colors.white
                                            .withValues(alpha: 0.35),
                                fontSize: 9,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⭐ LAST 10 NIGHTS SPECIAL CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLast10NightsCard(RamadanState r) {
    final isOdd = r.isOddNight;
    final nightNum = r.currentDay - (r.totalDays - 10);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _last10Purple,
            _last10Purple.withValues(alpha: 0.7),
            const Color(0xFF4C1D95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _last10Purple.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last 10 Nights · Night $nightNum',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isOdd
                          ? '✨ ODD NIGHT — Seek Laylatul Qadr!'
                          : 'Increase your worship every night',
                      style: TextStyle(
                        color:
                            Colors.white.withValues(alpha: isOdd ? 1.0 : 0.7),
                        fontSize: 12,
                        fontWeight: isOdd ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Odd night indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [21, 23, 25, 27, 29].map((night) {
              final dayForNight = r.totalDays - 10 + night - 20;
              final isCurrentNight = r.currentDay == dayForNight;
              final isPast = r.currentDay > dayForNight;
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentNight
                          ? Colors.white.withValues(alpha: 0.2)
                          : isPast
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.04),
                      border: isCurrentNight
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$night',
                        style: TextStyle(
                          color: Colors.white.withValues(
                              alpha: isCurrentNight ? 1.0 : 0.5),
                          fontSize: 12,
                          fontWeight: isCurrentNight
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isCurrentNight)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Dua
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '\"اللَّهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ الْعَفْوَ فَاعْفُ عَنِّي\"\nO Allah, You are pardoning and love to pardon, so pardon me.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 SHARED UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _glassCard({
    required Color accent,
    required Widget child,
    EdgeInsets margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.04),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _groupLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(
        color: Colors.white.withValues(alpha: 0.06),
        height: 1,
      ),
    );
  }

  Widget _checkCircle(bool checked, Color accent) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? accent : Colors.white.withValues(alpha: 0.06),
        border:
            checked ? null : Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: checked
          ? const Icon(Icons.check, color: Colors.white, size: 13)
          : null,
    );
  }

  Widget _checkRow(String label, bool checked, Color accent,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: checked
              ? accent.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.015),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: checked
                ? accent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            _checkCircle(checked, accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: checked
                      ? _warmCream.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: checked ? FontWeight.w500 : FontWeight.w400,
                  decoration:
                      checked ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: accent.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ✨ STARFIELD PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _StarfieldPainter extends CustomPainter {
  final double animValue;
  final bool isLast10;

  _StarfieldPainter({required this.animValue, required this.isLast10});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); // fixed seed for stable positions
    final paint = Paint()..style = PaintingStyle.fill;

    // Draw 60 stars
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6; // top 60%
      final baseRadius = rng.nextDouble() * 1.2 + 0.3;
      final phase = rng.nextDouble();
      final twinkle = (sin((animValue + phase) * pi * 2) + 1) / 2;
      final alpha = 0.1 + twinkle * 0.4;
      final radius = baseRadius * (0.7 + twinkle * 0.3);

      paint.color = isLast10
          ? Color.lerp(
              const Color(0xFFE8DAEF),
              const Color(0xFFF5E6C8),
              rng.nextDouble(),
            )!
              .withValues(alpha: alpha)
          : const Color(0xFFF5E6C8).withValues(alpha: alpha);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // Subtle mosque silhouette at bottom
    _drawMosqueSilhouette(canvas, size);
  }

  void _drawMosqueSilhouette(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final baseY = h - 20;

    final path = Path();
    path.moveTo(0, baseY);

    // Dome 1 (left)
    path.lineTo(w * 0.15, baseY);
    path.quadraticBezierTo(w * 0.2, baseY - 25, w * 0.25, baseY);

    // Central dome
    path.lineTo(w * 0.35, baseY);
    path.lineTo(w * 0.38, baseY - 10);
    path.quadraticBezierTo(w * 0.5, baseY - 50, w * 0.62, baseY - 10);
    path.lineTo(w * 0.65, baseY);

    // Minaret
    path.lineTo(w * 0.68, baseY);
    path.lineTo(w * 0.69, baseY - 40);
    path.lineTo(w * 0.71, baseY - 40);
    path.lineTo(w * 0.72, baseY);

    // Dome 2 (right)
    path.lineTo(w * 0.78, baseY);
    path.quadraticBezierTo(w * 0.83, baseY - 20, w * 0.88, baseY);

    path.lineTo(w, baseY);
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.animValue != animValue;
}
