import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/dhikr_counter_widget.dart';
import 'dhikr_history_pro_dashboard_redesigned.dart';

/// Full-screen Dhikr Counter — Immersive counting experience
/// Navigated to from the DhikrSummaryWidget on the dashboard.
class DhikrCounterScreen extends ConsumerWidget {
  const DhikrCounterScreen({super.key});

  static const Color _surfaceBg = Color(0xFF0A0A0A);
  static const Color _gold = Color(0xFFC2A366);
  static const Color _textMuted = Color(0xFF484F58);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Dhikr Counter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  // History / Dashboard button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const DhikrHistoryProDashboard(),
                          transitionsBuilder: (_, anim, __, child) {
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 280),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: _gold.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Dhikr Counter Widget — centered ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: const DhikrCounterWidget(),
                  ),
                ),
              ),
            ),

            // ── Bottom hint ──
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Tap the counter to count  •  Swipe pills to change dhikr',
                style: TextStyle(
                  fontSize: 10,
                  color: _textMuted.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
