import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/weekly_report_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Weekly Spiritual Report
///
/// Apple-style ruler week selector at the top: numbers scroll horizontally,
/// centre item is highlighted in accent colour (larger + bold), outer items
/// fade and shrink — exactly like the iOS time-picker drum roll.
/// Selecting a week loads that week's spiritual data below.
class WeeklySpiritualReportScreen extends ConsumerStatefulWidget {
  const WeeklySpiritualReportScreen({super.key});

  @override
  ConsumerState<WeeklySpiritualReportScreen> createState() =>
      _WeeklySpiritualReportScreenState();
}

class _WeeklySpiritualReportScreenState
    extends ConsumerState<WeeklySpiritualReportScreen> {
  // How many past weeks to show (0 = this week, negative offsets)
  static const int _maxPastWeeks = 11; // show 12 weeks total (this + 11 past)

  // Selected offset: 0 = this week, -1 = last week, …, -11 = 11 weeks ago
  int _selectedOffset = 0;

  // ScrollController for the ruler
  late final ScrollController _rulerCtrl;

  // Width of each ruler item — set in layout
  static const double _itemW = 64.0;

  @override
  void initState() {
    super.initState();
    // Start at offset=0 (this week), which is the last item in the list.
    // List order: oldest first → newest last, so index = _maxPastWeeks (index of 0 offset)
    final initialIndex = _maxPastWeeks; // offset 0 is at the end
    _rulerCtrl = ScrollController(
      initialScrollOffset: initialIndex * _itemW,
    );
  }

  @override
  void dispose() {
    _rulerCtrl.dispose();
    super.dispose();
  }

  // Snap to the nearest item on scroll end
  void _onScrollEnd() {
    final rawIndex = _rulerCtrl.offset / _itemW;
    final snapped = rawIndex.round().clamp(0, _maxPastWeeks);
    final snapOffset = snapped * _itemW;
    if ((_rulerCtrl.offset - snapOffset).abs() > 0.5) {
      _rulerCtrl.animateTo(
        snapOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    final newOffset = -((_maxPastWeeks) - snapped); // convert index → week offset
    if (newOffset != _selectedOffset) {
      setState(() => _selectedOffset = newOffset);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final report = ref.watch(weeklyReportForOffsetProvider(_selectedOffset));

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, accent, report),

              // ── Apple-style ruler week selector ──────────────────
              _WeekRuler(
                controller: _rulerCtrl,
                accent: accent,
                maxPastWeeks: _maxPastWeeks,
                selectedOffset: _selectedOffset,
                onScrollEnd: _onScrollEnd,
                onOffsetChanged: (o) {
                  if (o != _selectedOffset) {
                    setState(() => _selectedOffset = o);
                    HapticFeedback.selectionClick();
                  }
                },
              ),

              // ── Report content ────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _ReportContent(
                    key: ValueKey(_selectedOffset),
                    report: report,
                    accent: accent,
                    ref: ref,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, Color accent, WeeklyReport report) {
    final isCurrent = _selectedOffset == 0;
    final fmt = DateFormat('MMM d');
    final label = isCurrent
        ? 'This Week'
        : '${fmt.format(report.weekStart)} – ${fmt.format(report.weekEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Report',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.insights_rounded,
              color: accent.withValues(alpha: 0.4), size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apple-style ruler week selector
// ─────────────────────────────────────────────────────────────────────────────
class _WeekRuler extends StatefulWidget {
  final ScrollController controller;
  final Color accent;
  final int maxPastWeeks;
  final int selectedOffset;
  final VoidCallback onScrollEnd;
  final ValueChanged<int> onOffsetChanged;

  const _WeekRuler({
    required this.controller,
    required this.accent,
    required this.maxPastWeeks,
    required this.selectedOffset,
    required this.onScrollEnd,
    required this.onOffsetChanged,
  });

  @override
  State<_WeekRuler> createState() => _WeekRulerState();
}

class _WeekRulerState extends State<_WeekRuler> {
  static const double _itemW = 64.0;
  static const double _rulerH = 80.0;

  // Total items = 0.._maxPastWeeks (inclusive) = maxPastWeeks+1 items
  int get _totalItems => widget.maxPastWeeks + 1;

  // Convert list index (0 = oldest) to week offset (negative = past)
  int _indexToOffset(int index) => -(widget.maxPastWeeks - index);

  // Week label for a given offset
  String _label(int offset) {
    final now = DateTime.now();
    final weekday = now.weekday;
    final daysSinceSat = (weekday + 1) % 7;
    final thisWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysSinceSat));
    final wkStart = thisWeekStart.add(Duration(days: offset * 7));
    return DateFormat('MMM d').format(wkStart);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    // Padding so the first/last item can reach the centre
    final sidePad = (screenW / 2) - (_itemW / 2);

    return SizedBox(
      height: _rulerH + 24, // ruler + tick marks below
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Tick marks + numbers ───────────────────────────────
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification) {
                // Snap on fling/drag end
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => widget.onScrollEnd());
              }
              if (n is ScrollUpdateNotification) {
                // Fire offset change while dragging (live preview)
                final rawIndex =
                    widget.controller.offset / _itemW;
                final idx = rawIndex.round().clamp(0, widget.maxPastWeeks);
                final offset = _indexToOffset(idx);
                widget.onOffsetChanged(offset);
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: _NoGlowBehavior(),
              child: ListView.builder(
                controller: widget.controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: sidePad),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                itemCount: _totalItems,
                itemBuilder: (context, index) {
                  final offset = _indexToOffset(index);
                  final isSelected = offset == widget.selectedOffset;
                  // Smooth distance-based scale/opacity via AnimatedBuilder
                  return _RulerItem(
                    controller: widget.controller,
                    index: index,
                    itemW: _itemW,
                    offset: offset,
                    label: _label(offset),
                    isSelected: isSelected,
                    accent: widget.accent,
                    isCurrent: offset == 0,
                    onTap: () {
                      widget.onOffsetChanged(offset);
                      widget.controller.animateTo(
                        index * _itemW,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // ── Centre selection highlight (two vertical lines) ──
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCentreLine(widget.accent),
                SizedBox(width: _itemW - 2),
                _buildCentreLine(widget.accent),
              ],
            ),
          ),

          // ── Left fade gradient ────────────────────────────────
          IgnorePointer(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: screenW * 0.28,
                height: _rulerH + 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black,
                      Colors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Right fade gradient ───────────────────────────────
          IgnorePointer(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: screenW * 0.28,
                height: _rulerH + 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentreLine(Color accent) {
    return Container(
      width: 1,
      height: 28,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: 0.55),
            accent.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single ruler item — uses AnimatedBuilder to read scroll position live
// and adjust its own scale / opacity like an Apple drum-roll picker
// ─────────────────────────────────────────────────────────────────────────────
class _RulerItem extends StatelessWidget {
  final ScrollController controller;
  final int index;
  final double itemW;
  final int offset;
  final String label;
  final bool isSelected;
  final bool isCurrent;
  final Color accent;
  final VoidCallback onTap;

  const _RulerItem({
    required this.controller,
    required this.index,
    required this.itemW,
    required this.offset,
    required this.label,
    required this.isSelected,
    required this.isCurrent,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        // Distance of this item's centre from the viewport centre
        double scrollOffset = 0;
        if (controller.hasClients && controller.position.hasPixels) {
          scrollOffset = controller.offset;
        }
        final screenW = MediaQuery.of(context).size.width;
        final viewportCentre = scrollOffset + screenW / 2;
        final itemCentre = index * itemW + itemW / 2;
        final dist = (viewportCentre - itemCentre).abs();

        // Scale: 1.0 at centre → 0.72 at ±2 items away
        final scale = (1.0 - (dist / (itemW * 3)).clamp(0.0, 1.0) * 0.28)
            .clamp(0.72, 1.0);
        // Opacity: 1.0 at centre → 0.18 at far
        final opacity = (1.0 - (dist / (itemW * 2.5)).clamp(0.0, 1.0) * 0.82)
            .clamp(0.18, 1.0);

        final atCentre = dist < itemW * 0.5;
        final textColor = atCentre
            ? accent
            : Colors.white.withValues(alpha: opacity * 0.85);

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: itemW,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Tick mark ──────────────────────────────
                Container(
                  width: atCentre ? 1.5 : 1,
                  height: atCentre ? 12 : 8,
                  color: atCentre
                      ? accent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: opacity * 0.25),
                ),
                const SizedBox(height: 6),

                // ── Week number (large) ─────────────────────
                Transform.scale(
                  scale: scale,
                  child: Text(
                    // Show the week number relative to current
                    offset == 0
                        ? 'Now'
                        : offset == -1
                            ? 'Last'
                            : '${offset.abs()}w',
                    style: TextStyle(
                      color: textColor,
                      fontSize: atCentre ? 18 : 15,
                      fontWeight: atCentre
                          ? FontWeight.w700
                          : FontWeight.w400,
                      letterSpacing: atCentre ? -0.3 : 0,
                    ),
                  ),
                ),
                const SizedBox(height: 2),

                // ── Date label (small) ──────────────────────
                Transform.scale(
                  scale: math.max(scale * 0.9, 0.7),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: atCentre
                          ? accent.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: opacity * 0.35),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── Bottom tick ─────────────────────────────
                Container(
                  width: atCentre ? 1.5 : 1,
                  height: atCentre ? 12 : 8,
                  color: atCentre
                      ? accent.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: opacity * 0.25),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Remove glow overscroll effect
class _NoGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report content — rendered below the ruler for the selected week
// ─────────────────────────────────────────────────────────────────────────────
class _ReportContent extends ConsumerWidget {
  final WeeklyReport report;
  final Color accent;
  final WidgetRef ref;

  const _ReportContent({
    super.key,
    required this.report,
    required this.accent,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        children: [
          _buildTicketCard(report, accent, context),
        ],
      ),
    );
  }

  // ─── Single Ticket Card ───────────────────────────────────────────────
  Widget _buildTicketCard(WeeklyReport report, Color accent, BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final startStr = dateFormat.format(report.weekStart);
    final endStr = dateFormat.format(report.weekEnd);
    final pct = (report.prayerPercentage * 100).toInt();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Section: Header & Dates
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BOARDING',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      startStr.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.flight_takeoff_rounded, color: accent.withValues(alpha: 0.5)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ARRIVAL',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      endStr.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Ticket Perforation Divider
          Row(
            children: [
              Container(
                width: 12,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dotCount = (constraints.constrainWidth() / 10).floor();
                    return Flex(
                      direction: Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(dotCount, (_) {
                        return SizedBox(
                          width: 4,
                          height: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.3),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              Container(
                width: 12,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
            ],
          ),

          // Main Stats Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Prayer Circular Score & Details
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: report.prayerPercentage.clamp(0, 1),
                            strokeWidth: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: AlwaysStoppedAnimation(accent),
                            strokeCap: StrokeCap.round,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRAYER COMPLETION',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${report.totalPrayers} / 35',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            report.spiritualLevel.toUpperCase(),
                            style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Dhikr Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.spa_rounded, color: accent.withValues(alpha: 0.7), size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WEEKLY DHIKR',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${report.totalDhikr} Total Count',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _dhikrEmoji(report.totalDhikr),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Motivation / Message Bottom Area
                Text(
                  '"${report.motivationalMessage}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dhikrEmoji(int count) {
    if (count >= 1000) return '👑';
    if (count >= 500) return '🏆';
    if (count >= 100) return '⚡';
    if (count > 0) return '🌟';
    return '🌱';
  }
}

