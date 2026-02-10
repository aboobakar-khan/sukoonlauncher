import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/prayer_tracker_widget.dart';
import '../widgets/dhikr_counter_widget.dart';
import 'premium_paywall_screen.dart';
import 'ramadan_dashboard_screen.dart';
import '../features/quran/providers/quran_provider.dart';
import '../features/quran/widgets/tafseer_bottom_sheet.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/ramadan_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/ambient_sound_widget.dart';


/// Widget Dashboard — Minimalist Redesign
/// Clean vertical flow with subtle section dividers.
/// Removed redundant DhikrAnalytics / PrayerAnalytics widgets
/// (both dashboards are already accessible from their parent widgets).
class WidgetDashboardScreen extends ConsumerWidget {
  const WidgetDashboardScreen({super.key});

  static const _gold = Color(0xFFC2A366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabicFont = ref.watch(arabicFontProvider);
    final isPremium = ref.watch(premiumProvider);
    final currentTheme = ref.watch(themeColorProvider);
    final ramadan = ref.watch(ramadanProvider);

    // 🌙 When Ramadan Mode is ON → show Ramadan Dashboard
    if (ramadan.isEnabled) {
      return const RamadanDashboardScreen();
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // ─── Verse of the Moment ───────────────────────
                  _buildVerseCard(ref, arabicFont),

                  _sectionGap(),

                  // ─── Prayer Tracker (UNTOUCHED) ────────────────
                  const PrayerTrackerWidget(),

                  _sectionGap(),

                  // ─── Dhikr Counter ─────────────────────────────
                  const DhikrCounterWidget(),

                  _sectionGap(),

                  // ─── Daily Challenges ──────────────────────────
                  const DailyIslamicChallengeCard(),

                  _sectionGap(),

                  // ─── Ambient Sound ─────────────────────────────
                  const AmbientSoundWidget(),

                  _sectionGap(),

                  // ─── Calendar ──────────────────────────────────
                  CalendarWidget(onExpand: () {}),

                  const SizedBox(height: 24),

                  // ─── Premium (non-premium only) ────────────────
                  if (!isPremium.isPremium) _buildPremiumRow(context),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Consistent section gap with faint divider ──
  Widget _sectionGap() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 36,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              _gold.withValues(alpha: 0.12),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    );
  }

  // ── Verse of the Moment — streamlined ──
  Widget _buildVerseCard(WidgetRef ref, dynamic arabicFont) {
    return Consumer(
      builder: (context, ref, child) {
        final verseAsync = ref.watch(randomVerseProvider);
        return verseAsync.when(
          data: (verse) {
            if (verse == null) return const SizedBox.shrink();
            return GestureDetector(
              onTap: () => ref.invalidate(randomVerseProvider),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.025),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: _gold.withValues(alpha: 0.6), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Verse of the Moment',
                          style: TextStyle(
                            color: _gold.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.12), size: 14),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Arabic text
                    Text(
                      verse['arabic'] as String,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 22,
                        height: 1.9,
                        fontWeight: FontWeight.w400,
                        fontFamily: arabicFont.fontFamily,
                      ),
                    ),
                    if (verse['translation'] != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        verse['translation'] as String,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Footer: surah ref + tafseer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${verse['surahTransliteration']} ${verse['verseNumber']}',
                          style: TextStyle(
                            color: _gold.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            TafseerBottomSheet.show(
                              context,
                              surahId: verse['surahId'] as int,
                              ayahId: verse['verseNumber'] as int,
                              surahName: verse['surahTransliteration'] as String,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_outlined, size: 12, color: _gold.withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text(
                                'Tafseer',
                                style: TextStyle(
                                  color: _gold.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
  }

  // ── Premium row — minimal ──
  Widget _buildPremiumRow(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => PremiumPaywallScreen(),
            transitionsBuilder: (context, anim, _, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: _gold.withValues(alpha: 0.6), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Upgrade to Premium',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: _gold.withValues(alpha: 0.3), size: 14),
          ],
        ),
      ),
    );
  }
}
