import 'package:flutter/material.dart';

// ─── Year Dots Wallpaper ─────────────────────────────────────────
// 365-dot grid (366 on leap year). One dot per day.
// Past days = solid. Today = accent. Future = faint.
// Recalculates ONLY on build (caller triggers via lifecycle).
// Zero timers. Zero background work. Pure static render.

/// Pure date logic — no UI, no framework dependency.
class YearProgress {
  YearProgress._();

  /// Whether [year] is a leap year.
  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Total days in [year].
  static int daysInYear(int year) => isLeapYear(year) ? 366 : 365;

  /// 1-based day-of-year for [date].
  static int dayOfYear(DateTime date) =>
      date.difference(DateTime(date.year, 1, 1)).inDays + 1;

  /// Snapshot of year state at a single instant.
  static ({int totalDays, int today, int year}) snapshot() {
    final now = DateTime.now();
    return (
      totalDays: daysInYear(now.year),
      today: dayOfYear(now),
      year: now.year,
    );
  }
}

/// Dot state for rendering.
enum _DotState { past, today, future }

/// Static 365-dot wallpaper widget.
/// Caller must trigger rebuild on app resume (setState or key change).
class YearDotsWallpaper extends StatelessWidget {
  final Color accentColor;

  const YearDotsWallpaper({super.key, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final data = YearProgress.snapshot();
    final totalDays = data.totalDays;
    final today = data.today;
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Grid layout: fixed 17 columns to match reference design density
    const int columns = 17;
    final int rows = (totalDays / columns).ceil();
    final totalCells = rows * columns;

    // Dot sizing — responsive to screen width
    final double spacing = 2.0;
    final double dotSize =
        (screenWidth - 32 - (columns - 1) * spacing) / columns;
    // Clamp dot size for visual consistency
    final double dot = dotSize.clamp(8.0, 14.0);

    return Container(
      color: const Color(0xFF050507),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: columns * (dot + spacing) - spacing,
            height: rows * (dot + spacing) - spacing,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
              ),
              itemCount: totalCells,
              itemBuilder: (_, index) {
                final dayNum = index + 1; // 1-based

                // Overflow cells beyond totalDays — render invisible
                if (dayNum > totalDays) {
                  return const SizedBox.shrink();
                }

                final _DotState state;
                if (dayNum < today) {
                  state = _DotState.past;
                } else if (dayNum == today) {
                  state = _DotState.today;
                } else {
                  state = _DotState.future;
                }

                return _Dot(state: state, accent: accentColor, size: dot);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Single dot — lightweight, no animations.
class _Dot extends StatelessWidget {
  final _DotState state;
  final Color accent;
  final double size;

  const _Dot({
    required this.state,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (state) {
      case _DotState.past:
        color = Colors.white.withValues(alpha: 0.55);
        break;
      case _DotState.today:
        color = accent;
        break;
      case _DotState.future:
        color = Colors.white.withValues(alpha: 0.08);
        break;
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

/// Mini preview version for the wallpaper picker card.
/// Renders a small 17×22 grid with tiny dots.
class YearDotsPreview extends StatelessWidget {
  const YearDotsPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final data = YearProgress.snapshot();
    final today = data.today;
    final totalDays = data.totalDays;
    const columns = 17;
    final rows = (totalDays / columns).ceil();
    final totalCells = rows * columns;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF050507),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Wrap(
          spacing: 1.5,
          runSpacing: 1.5,
          children: List.generate(totalCells, (i) {
            final day = i + 1;
            if (day > totalDays) return const SizedBox(width: 4, height: 4);

            final Color c;
            if (day < today) {
              c = Colors.white.withValues(alpha: 0.5);
            } else if (day == today) {
              c = Colors.orange;
            } else {
              c = Colors.white.withValues(alpha: 0.08);
            }

            return Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(shape: BoxShape.circle, color: c),
            );
          }),
        ),
      ),
    );
  }
}
