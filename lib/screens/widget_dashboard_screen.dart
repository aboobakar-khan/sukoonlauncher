import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/daily_challenge_card.dart';
import '../widgets/prayer_tracker_widget.dart';
import '../widgets/dhikr_counter_widget.dart';
import '../widgets/dhikr_analytics_widget.dart';
import '../widgets/prayer_analytics_widget.dart';
import 'premium_paywall_screen.dart';
import '../features/quran/providers/quran_provider.dart';
import '../features/quran/widgets/tafseer_bottom_sheet.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/ambient_sound_widget.dart';

/// Widget Dashboard - 🐪 Camel Oasis productivity screen
/// Contains cards for To-Do, Notes, Calendar, etc.
class WidgetDashboardScreen extends ConsumerWidget {
  const WidgetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabicFont = ref.watch(arabicFontProvider);
    final isPremium = ref.watch(premiumProvider);
    final currentTheme = ref.watch(themeColorProvider);

    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Widget grid
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Tap for next Verse
                  Consumer(
                    builder: (context, ref, child) {
                      final verseAsync = ref.watch(randomVerseProvider);
                      return verseAsync.when(
                        data: (verse) {
                          if (verse == null) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () {
                              ref.invalidate(randomVerseProvider);
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFC2A366).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Color(0xFFC2A366),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Verse of the Moment',
                                        style: TextStyle(
                                          color: const Color(0xFFC2A366).withValues(alpha: 0.7),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white.withValues(alpha: 0.15),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  // Decorative divider
                                  Center(
                                    child: Container(
                                      width: 50,
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                          Colors.transparent,
                                          const Color(0xFFC2A366).withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ]),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    verse['arabic'] as String,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      height: 2.0,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: arabicFont.fontFamily,
                                    ),
                                  ),
                                  if (verse['translation'] != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      textAlign: TextAlign.left,
                                      verse['translation'] as String,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${verse['surahTransliteration']} ${verse['verseNumber']}',
                                        style: TextStyle(
                                          color: const Color(0xFFC2A366).withValues(alpha: 0.6),
                                          fontSize: 12,
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
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFA67B5B).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFC2A366).withValues(alpha: 0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.menu_book_outlined,
                                                size: 14,
                                                color: const Color(0xFFC2A366),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tafseer',
                                                style: TextStyle(
                                                  color: const Color(0xFFC2A366),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
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
                  ),

                  // Prayer Tracker Widget - Track daily prayers (TOP PRIORITY)
                  const PrayerTrackerWidget(),
                  
                  // Dhikr Counter Widget - Digital tasbih (TOP PRIORITY)
                  const DhikrCounterWidget(),
                  
                  // Daily Islamic Challenges - Gamified habit building (placed after dhikr)
                  const DailyIslamicChallengeCard(),

                  const SizedBox(height: 16),

                  // Ambient Sound - soothing Islamic background audio
                  const AmbientSoundWidget(),

                  const SizedBox(height: 16),

                  // Calendar (full width)
                  CalendarWidget(
                    onExpand: () {
                    },
                  ),

                  const SizedBox(height: 16),

                  // Future widgets can go here
                  // App Usage, Habits, etc.

                  // Dhikr Analytics PRO Widget
                  const DhikrAnalyticsWidget(),

                  // Prayer Analytics Widget
                  const PrayerAnalyticsWidget(),

                  // Premium card (only show if not premium)
                  if (!isPremium.isPremium) _buildPremiumCard(context, currentTheme),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, AppThemeColor currentTheme) {
    const gold = Color(0xFFC2A366);
    
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: gold.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.workspace_premium_rounded, color: gold, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Unlock all themes, Deen Mode & more',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: gold.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
