import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tasbih_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/dhikr_counter_screen.dart';

/// Dhikr Summary Widget — Minimalist card for the main dashboard
/// Shows today's stats at a glance. Tap to open full counter.
class DhikrSummaryWidget extends ConsumerWidget {
  const DhikrSummaryWidget({super.key});

  // ☪️ Design tokens
  static const Color _gold = Color(0xFFC2A366);
  static const Color _goldLight = Color(0xFFE8D5B7);
  static const Color _green = Color(0xFF7BAE6E);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _textMuted = Color(0xFF484F58);
  static const Color _borderColor = Color(0xFF1E1E1E);

  static const List<String> _dhikrNames = [
    'SubhanAllah', 'Alhamdulillah', 'Allahu Akbar',
    'La ilaha illallah', 'Astaghfirullah', 'SubhanAllahi wa bihamdihi',
    'SubhanAllahil Azeem', 'La hawla wa la quwwata illa billah',
    'HasbunAllahu wa ni\'mal wakeel', 'Allahumma salli ala Muhammad',
    'La ilaha illallahu wahdahu...', 'Rabbighfirli wa tub alayya',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ref.watch(themeColorProvider);
    final tasbih = ref.watch(tasbihProvider);
    final progress = tasbih.currentCount / tasbih.targetCount;
    final done = tasbih.currentCount >= tasbih.targetCount;
    final currentDhikr = _dhikrNames[tasbih.selectedDhikrIndex % _dhikrNames.length];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DhikrCounterScreen(),
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
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          children: [
            // ── Header row ──
            Row(
              children: [
                // Title
                Text(
                  'DHIKR',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                    color: themeColor.color.withOpacity(0.7),
                  ),
                ),
                if (tasbih.streakDays > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '🔥 ${tasbih.streakDays}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _gold.withOpacity(0.7),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  'Tap to count',
                  style: TextStyle(
                    fontSize: 10,
                    color: _textMuted.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _textMuted.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Stats row — Today + Progress + Total ──
            Row(
              children: [
                // Today's count
                Expanded(
                  child: _buildStatColumn(
                    label: 'Today',
                    value: _formatNumber(tasbih.todayCount),
                    color: _gold,
                  ),
                ),

                // Progress ring — compact
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(56, 56),
                        painter: _MiniArcPainter(
                          progress: math.min(progress, 1.0),
                          bgColor: _borderColor,
                          fgColor: done ? _green : _gold,
                          stroke: 3,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${tasbih.currentCount}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              color: done ? _green : _textPrimary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            '/ ${tasbih.targetCount}',
                            style: const TextStyle(fontSize: 8, color: _textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Total all-time
                Expanded(
                  child: _buildStatColumn(
                    label: 'Total',
                    value: _formatNumber(tasbih.totalAllTime),
                    color: _goldLight,
                    align: CrossAxisAlignment.end,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Current dhikr label ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _gold.withOpacity(0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: _gold.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentDhikr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _goldLight.withOpacity(0.8),
                    ),
                  ),
                  if (done) ...[
                    const SizedBox(width: 6),
                    Text(
                      '✓ Done',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _green.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    required String label,
    required String value,
    required Color color,
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w500,
            color: _textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w300,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

/// Compact arc painter for summary widget
class _MiniArcPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final double stroke;

  _MiniArcPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = fgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniArcPainter old) =>
      old.progress != progress || old.fgColor != fgColor;
}
