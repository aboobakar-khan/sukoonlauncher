import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/todo_widget.dart';
import '../widgets/notes_widget.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/pomodoro_widget.dart';
import '../widgets/focus_mode_widget.dart';
import '../widgets/deen_mode_widget.dart';
import '../widgets/event_tracker_widget.dart';
import '../widgets/tasbih_counter_widget.dart';
import '../widgets/prayer_tracker_widget.dart';
import '../widgets/screen_time_widget.dart';
import 'todo_list_screen.dart';
import 'prayer_tracker_screen.dart';
import 'premium_paywall_screen.dart';
import '../features/quran/providers/quran_provider.dart';
import '../features/quran/widgets/tafseer_bottom_sheet.dart';
import '../providers/arabic_font_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/theme_provider.dart';

/// Widget Dashboard - Oasis-style productivity screen
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
                              // Invalidate the provider to get a new random verse
                              ref.invalidate(randomVerseProvider);
                            },
                            child: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color.fromARGB(
                                    255,
                                    133,
                                    252,
                                    137,
                                  ).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: const Color.fromARGB(
                                          255,
                                          133,
                                          252,
                                          137,
                                        ),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tap for next Verse',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    verse['arabic'] as String,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 25,
                                      height: 1.8,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: arabicFont.fontFamily,
                                    ),
                                  ),
                                  if (verse['translation'] != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      textAlign: TextAlign.left,
                                      verse['translation'] as String,
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${verse['surahTransliteration']} ${verse['verseNumber']}',
                                        style: TextStyle(
                                          color: const Color.fromARGB(
                                            255,
                                            133,
                                            252,
                                            137,
                                          ),
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
                                            color: const Color(0xFF30A14E).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFF40C463).withValues(alpha: 0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.menu_book_outlined,
                                                size: 14,
                                                color: const Color(0xFF40C463),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tafseer',
                                                style: TextStyle(
                                                  color: const Color(0xFF40C463),
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

                  // Prayer Tracker Widget - 5 times daily prayer tracking
                  PrayerTrackerWidget(
                    onExpand: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PrayerTrackerScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Tasbih Counter Widget - Dhikr counting
                  const TasbihCounterWidget(),

                  // Todo Widget
                  TodoWidget(
                    onExpand: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const TodoListScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Notes Widget
                  NotesWidget(
                    onExpand: () {
                      // TODO: Navigate to full notes screen
                    },
                  ),

                  const SizedBox(height: 16),

                  // Pomodoro Timer Widget
                  PomodoroWidget(
                    onExpand: () {
                      // TODO: Navigate to full pomodoro screen
                    },
                  ),

                  // Focus Mode Widget (near Pomodoro for productivity)
                  const FocusModeWidget(),

                  // Deen Mode Widget (spiritual focus)
                  const DeenModeWidget(),

                  const SizedBox(height: 16),

                  // Event Tracker Widget
                  EventTrackerWidget(
                    onExpand: () {
                      // TODO: Navigate to full events screen
                    },
                  ),

                  const SizedBox(height: 16),

                  // Calendar (full width)
                  CalendarWidget(
                    onExpand: () {
                      // TODO: Navigate to full calendar screen
                    },
                  ),

                  const SizedBox(height: 16),

                  // Future widgets can go here
                  // App Usage, Habits, etc.

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
    const greenAccent = Color(0xFF40C463);
    
    return GestureDetector(
      onTap: () {
        // Open new psychology-optimized paywall
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) => const PremiumPaywallScreen(),
            transitionsBuilder: (context, anim, _, child) {
              return FadeTransition(opacity: anim, child: child);
            },
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              greenAccent.withValues(alpha: 0.15),
              greenAccent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: greenAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Premium icon with glow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF40C463), Color(0xFF30A14E)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: greenAccent.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            
            // Title with badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Go Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '75% OFF',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Text(
              'Unlock Deen Mode, all themes & more',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            
            // Social proof
            Text(
              '⭐ 10K+ Muslims already upgraded',
              style: TextStyle(
                color: greenAccent.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            
            // CTA Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF40C463), Color(0xFF30A14E)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: greenAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'VIEW PLANS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
