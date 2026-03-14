import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../providers/time_format_provider.dart';

/// Digital Clock Widget - Classic digital display
class DigitalClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const DigitalClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _dayOfWeek => DateFormat('EEEE').format(time).toUpperCase();
  String get _date => DateFormat('MMMM d').format(time);
  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm a').format(time)
      : DateFormat('HH:mm').format(time);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _dayOfWeek,
          style: TextStyle(
            fontSize: 48,
            letterSpacing: 8,
            fontWeight: FontWeight.w200,
            color: themeColor.color.withValues(alpha: opacityMultiplier),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _date,
          style: TextStyle(
            fontSize: 20,
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.6 * opacityMultiplier),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _time,
          style: TextStyle(
            fontSize: 24,
            letterSpacing: 3,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: opacityMultiplier),
          ),
        ),
      ],
    );
  }
}

/// Analog Clock Widget - Traditional clock face
class AnalogClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final double opacityMultiplier;

  const AnalogClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    this.opacityMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Clock face
        SizedBox(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: ClockPainter(time: time, themeColor: themeColor),
          ),
        ),
        const SizedBox(height: 24),
        // Date below clock
        Text(
          DateFormat('EEEE, MMMM d').format(time),
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.7 * opacityMultiplier),
          ),
        ),
      ],
    );
  }
}

/// Minimalist Clock Widget - Minimal design
class MinimalistClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const MinimalistClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm a').format(time)
      : DateFormat('HH:mm').format(time);
  String get _date => DateFormat('EEE, MMM d').format(time);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _time,
          style: TextStyle(
            fontSize: 72,
            letterSpacing: 6,
            fontWeight: FontWeight.w200,
            color: themeColor.color.withValues(alpha: opacityMultiplier),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _date,
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w400,
            color: themeColor.color.withValues(alpha: 0.70 * opacityMultiplier),
          ),
        ),
      ],
    );
  }
}

/// Bold Clock Widget - Large and prominent
class BoldClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const BoldClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm a').format(time)
      : DateFormat('HH:mm').format(time);
  String get _dayOfWeek => DateFormat('EEEE').format(time).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _time,
          style: TextStyle(
            fontSize: 96,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
            color: themeColor.color.withValues(alpha: opacityMultiplier),
            height: 1,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _dayOfWeek,
          style: TextStyle(
            fontSize: 24,
            letterSpacing: 6,
            fontWeight: FontWeight.w500,
            color: themeColor.color.withValues(alpha: 0.6 * opacityMultiplier),
          ),
        ),
      ],
    );
  }
}

/// Compact Clock Widget - Space-saving layout
class CompactClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const CompactClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm a').format(time)
      : DateFormat('HH:mm').format(time);
  String get _date => DateFormat('MMM d').format(time);
  String get _day => DateFormat('EEE').format(time);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _time,
          style: TextStyle(
            fontSize: 60,
            letterSpacing: 1,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: opacityMultiplier),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _day.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                letterSpacing: 2,
                fontWeight: FontWeight.w400,
                color: themeColor.color.withValues(
                  alpha: 0.7 * opacityMultiplier,
                ),
              ),
            ),
            Text(
              _date,
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1,
                fontWeight: FontWeight.w300,
                color: themeColor.color.withValues(
                  alpha: 0.5 * opacityMultiplier,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for analog clock
class ClockPainter extends CustomPainter {
  final DateTime time;
  final AppThemeColor themeColor;

  ClockPainter({required this.time, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    // Draw clock circle
    final circlePaint = Paint()
      ..color = themeColor.color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 10, circlePaint);

    // Draw hour markers
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * pi / 180;
      final start = Offset(
        center.dx + (radius - 20) * cos(angle),
        center.dy + (radius - 20) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 10) * cos(angle),
        center.dy + (radius - 10) * sin(angle),
      );
      final markerPaint = Paint()
        ..color = themeColor.color.withValues(alpha: 0.9)
        ..strokeWidth = 2;
      canvas.drawLine(start, end, markerPaint);
    }

    // Draw hour hand
    final hourAngle =
        ((time.hour % 12) * 30 + time.minute * 0.5 - 90) * pi / 180;
    final hourHand = Offset(
      center.dx + radius * 0.4 * cos(hourAngle),
      center.dy + radius * 0.4 * sin(hourAngle),
    );
    final hourPaint = Paint()
      ..color = themeColor.color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, hourHand, hourPaint);

    // Draw minute hand
    final minuteAngle = (time.minute * 6 - 90) * pi / 180;
    final minuteHand = Offset(
      center.dx + radius * 0.6 * cos(minuteAngle),
      center.dy + radius * 0.6 * sin(minuteAngle),
    );
    final minutePaint = Paint()
      ..color = themeColor.color.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, minuteHand, minutePaint);

    // Draw center dot
    final centerPaint = Paint()..color = themeColor.color;
    canvas.drawCircle(center, 6, centerPaint);
  }

  @override
  bool shouldRepaint(ClockPainter oldDelegate) => true;
}

/// Modern Clock Widget - Sleek contemporary style
class ModernClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const ModernClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm').format(time)
      : DateFormat('HH:mm').format(time);
  String get _period =>
      timeFormat == TimeFormat.hour12 ? DateFormat('a').format(time) : '';
  String get _seconds => DateFormat('ss').format(time);
  String get _date => DateFormat('EEEE, MMMM d').format(time);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _time,
              style: TextStyle(
                fontSize: 80,
                letterSpacing: 2,
                fontWeight: FontWeight.w200,
                color: themeColor.color.withValues(alpha: opacityMultiplier),
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _seconds,
                    style: TextStyle(
                      fontSize: 24,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w200,
                      color: themeColor.color.withValues(
                        alpha: 0.5 * opacityMultiplier,
                      ),
                    ),
                  ),
                  if (_period.isNotEmpty)
                    Text(
                      _period,
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w300,
                        color: themeColor.color.withValues(
                          alpha: 0.6 * opacityMultiplier,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: themeColor.color.withValues(
                alpha: 0.3 * opacityMultiplier,
              ),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _date,
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w300,
              color: themeColor.color.withValues(
                alpha: 0.7 * opacityMultiplier,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Retro Clock Widget - Vintage flip-clock style
class RetroClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const RetroClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _hour => timeFormat == TimeFormat.hour12
      ? DateFormat('hh').format(time)
      : DateFormat('HH').format(time);
  String get _minute => DateFormat('mm').format(time);
  String get _period =>
      timeFormat == TimeFormat.hour12 ? DateFormat('a').format(time) : '';
  String get _date => DateFormat('EEE, MMM d').format(time).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFlipDigit(_hour[0]),
            const SizedBox(width: 4),
            _buildFlipDigit(_hour[1]),
            const SizedBox(width: 16),
            Text(
              ':',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.w700,
                color: themeColor.color.withValues(
                  alpha: 0.9 * opacityMultiplier,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildFlipDigit(_minute[0]),
            const SizedBox(width: 4),
            _buildFlipDigit(_minute[1]),
          ],
        ),
        if (_period.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _period,
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: themeColor.color.withValues(
                alpha: 0.9 * opacityMultiplier,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          _date,
          style: TextStyle(
            fontSize: 15,
            letterSpacing: 3,
            fontWeight: FontWeight.w400,
            color: themeColor.color.withValues(alpha: 0.9 * opacityMultiplier),
          ),
        ),
      ],
    );
  }

  Widget _buildFlipDigit(String digit) {
    return Container(
      width: 54,
      height: 75,
      decoration: BoxDecoration(
        color: themeColor.color.withValues(alpha: 0.2 * opacityMultiplier),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: themeColor.color.withValues(alpha: 0.5 * opacityMultiplier),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          digit,
          style: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.w700,
            color: themeColor.color.withValues(alpha: opacityMultiplier),
          ),
        ),
      ),
    );
  }
}

/// Elegant Clock Widget - Refined and sophisticated
class ElegantClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const ElegantClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm').format(time)
      : DateFormat('HH:mm').format(time);
  String get _period =>
      timeFormat == TimeFormat.hour12 ? DateFormat('a').format(time) : '';
  String get _dayOfWeek => DateFormat('EEEE').format(time);
  String get _date => DateFormat('MMMM d, y').format(time);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _dayOfWeek,
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 4,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.5 * opacityMultiplier),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _time,
              style: TextStyle(
                fontSize: 68,
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
                color: themeColor.color.withValues(alpha: opacityMultiplier),
                fontFeatures: const [FontFeature.proportionalFigures()],
              ),
            ),
            if (_period.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 8),
                child: Text(
                  _period,
                  style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w300,
                    color: themeColor.color.withValues(
                      alpha: 0.6 * opacityMultiplier,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          width: 120,
          color: themeColor.color.withValues(alpha: 0.3 * opacityMultiplier),
        ),
        const SizedBox(height: 8),
        Text(
          _date,
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.5 * opacityMultiplier),
          ),
        ),
      ],
    );
  }
}

/// Binary Clock Widget - Geek mode - binary time
class BinaryClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const BinaryClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'BINARY TIME',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.4 * opacityMultiplier),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBinaryColumn('H', time.hour ~/ 10, 2),
            const SizedBox(width: 8),
            _buildBinaryColumn('', time.hour % 10, 4),
            const SizedBox(width: 20),
            _buildBinaryColumn('M', time.minute ~/ 10, 3),
            const SizedBox(width: 8),
            _buildBinaryColumn('', time.minute % 10, 4),
            const SizedBox(width: 20),
            _buildBinaryColumn('S', time.second ~/ 10, 3),
            const SizedBox(width: 8),
            _buildBinaryColumn('', time.second % 10, 4),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          timeFormat == TimeFormat.hour12
              ? DateFormat('h:mm:ss a').format(time)
              : DateFormat('HH:mm:ss').format(time),
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.5 * opacityMultiplier),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEE, MMM d').format(time),
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w300,
            color: themeColor.color.withValues(alpha: 0.4 * opacityMultiplier),
          ),
        ),
      ],
    );
  }

  Widget _buildBinaryColumn(String label, int value, int bits) {
    return Column(
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w400,
                color: themeColor.color.withValues(
                  alpha: 0.5 * opacityMultiplier,
                ),
              ),
            ),
          ),
        ...List.generate(bits, (index) {
          final bitIndex = bits - 1 - index;
          final isOn = (value & (1 << bitIndex)) != 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isOn
                    ? themeColor.color.withValues(alpha: opacityMultiplier)
                    : themeColor.color.withValues(
                        alpha: 0.1 * opacityMultiplier,
                      ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: themeColor.color.withValues(
                    alpha: 0.3 * opacityMultiplier,
                  ),
                  width: 1,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Progress Clock Widget — Circular arc that fills with time
/// The outer ring fills based on minutes (0–60 = 0%–100%),
/// inner ring fills based on hours (0–24 = 0%–100%).
/// Dynamic, responds in real-time like the homescreen screenshot.
class ProgressClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const ProgressClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h:mm').format(time)
      : DateFormat('HH:mm').format(time);

  String get _date {
    final day = time.day;
    final suffix = (day >= 11 && day <= 13)
        ? 'th'
        : ['th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th'][day % 10];
    return DateFormat("EEEE, d'$suffix' MMMM").format(time);
  }

  @override
  Widget build(BuildContext context) {
    // Minute progress: 0.0 → 1.0 over 60 minutes (with seconds for smooth)
    final minuteProgress = (time.minute + time.second / 60.0) / 60.0;
    // Hour progress: 0.0 → 1.0 over 12 hours (for 12h feel)
    final hour12 = time.hour % 12;
    final hourProgress = (hour12 + time.minute / 60.0) / 12.0;

    final color = themeColor.color;
    final alpha = opacityMultiplier;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Outer ring: minute progress ──
          SizedBox(
            width: 210,
            height: 210,
            child: CustomPaint(
              painter: _ProgressArcPainter(
                progress: minuteProgress,
                color: color.withValues(alpha: 0.9 * alpha),
                trackColor: color.withValues(alpha: 0.1 * alpha),
                strokeWidth: 2.5,
              ),
            ),
          ),

          // ── Inner ring: hour progress ──
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: _ProgressArcPainter(
                progress: hourProgress,
                color: color.withValues(alpha: 0.4 * alpha),
                trackColor: color.withValues(alpha: 0.06 * alpha),
                strokeWidth: 1.5,
              ),
            ),
          ),

          // ── Center text ──
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _time,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color: color.withValues(alpha: alpha),
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _date,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.3,
                  color: color.withValues(alpha: 0.5 * alpha),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the progress arc (used by ProgressClockWidget)
class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _ProgressArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle, faded)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(_ProgressArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color;
}

// ═══════════════════════════════════════════════════════
//  VERTICAL CLOCK — Stacked digits, editorial magazine feel
// ═══════════════════════════════════════════════════════

class VerticalClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const VerticalClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _hour => timeFormat == TimeFormat.hour12
      ? DateFormat('h').format(time)
      : DateFormat('HH').format(time);
  String get _minute => DateFormat('mm').format(time);
  String get _period =>
      timeFormat == TimeFormat.hour12 ? DateFormat('a').format(time) : '';

  @override
  Widget build(BuildContext context) {
    final color = themeColor.color;
    final a = opacityMultiplier;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _hour,
          style: TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.w100,
            height: 0.9,
            letterSpacing: -2,
            color: color.withValues(alpha: a),
          ),
        ),
        Container(
          width: 40,
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: color.withValues(alpha: 0.25 * a),
        ),
        Text(
          _minute,
          style: TextStyle(
            fontSize: 100,
            fontWeight: FontWeight.w100,
            height: 0.9,
            letterSpacing: -2,
            color: color.withValues(alpha: 0.6 * a),
          ),
        ),
        if (_period.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _period,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: color.withValues(alpha: 0.4 * a),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          DateFormat('EEE, MMM d').format(time),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            color: color.withValues(alpha: 0.35 * a),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  WORD CLOCK — Time spoken in English words
// ═══════════════════════════════════════════════════════

class WordClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const WordClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  static const _ones = [
    '', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE',
    'SIX', 'SEVEN', 'EIGHT', 'NINE', 'TEN',
    'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN', 'FIFTEEN',
    'SIXTEEN', 'SEVENTEEN', 'EIGHTEEN', 'NINETEEN',
  ];
  static const _tens = [
    '', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY',
  ];

  String _numberToWord(int n) {
    if (n == 0) return "O'CLOCK";
    if (n < 20) return _ones[n];
    final t = _tens[n ~/ 10];
    final o = _ones[n % 10];
    return o.isEmpty ? t : '$t $o';
  }

  String _hourWord(int h) {
    final h12 = h % 12;
    return _ones[h12 == 0 ? 12 : h12];
  }

  @override
  Widget build(BuildContext context) {
    final color = themeColor.color;
    final a = opacityMultiplier;
    final h = time.hour;
    final m = time.minute;
    final isPM = h >= 12;

    final hourLine = _hourWord(h);
    final minuteLine = _numberToWord(m);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "IT IS"
        Text(
          'IT IS',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 6,
            fontWeight: FontWeight.w300,
            color: color.withValues(alpha: 0.35 * a),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          hourLine,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w200,
            letterSpacing: 3,
            height: 1.1,
            color: color.withValues(alpha: a),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          minuteLine,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
            color: color.withValues(alpha: 0.6 * a),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isPM ? 'IN THE ${h >= 17 ? "EVENING" : "AFTERNOON"}' : 'IN THE MORNING',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 3,
            fontWeight: FontWeight.w300,
            color: color.withValues(alpha: 0.3 * a),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DOT MATRIX CLOCK — LED dot-grid display
// ═══════════════════════════════════════════════════════

class DotMatrixClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const DotMatrixClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  // 5×7 dot patterns for digits 0-9 and colon
  static const _patterns = <String, List<List<int>>>{
    '0': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,1,1],[1,0,1,0,1],[1,1,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
    '1': [[0,0,1,0,0],[0,1,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,1,1,1,0]],
    '2': [[0,1,1,1,0],[1,0,0,0,1],[0,0,0,0,1],[0,0,1,1,0],[0,1,0,0,0],[1,0,0,0,0],[1,1,1,1,1]],
    '3': [[0,1,1,1,0],[1,0,0,0,1],[0,0,0,0,1],[0,0,1,1,0],[0,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
    '4': [[0,0,0,1,0],[0,0,1,1,0],[0,1,0,1,0],[1,0,0,1,0],[1,1,1,1,1],[0,0,0,1,0],[0,0,0,1,0]],
    '5': [[1,1,1,1,1],[1,0,0,0,0],[1,1,1,1,0],[0,0,0,0,1],[0,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
    '6': [[0,1,1,1,0],[1,0,0,0,0],[1,0,0,0,0],[1,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
    '7': [[1,1,1,1,1],[0,0,0,0,1],[0,0,0,1,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0]],
    '8': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
    '9': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,1],[0,0,0,0,1],[0,0,0,0,1],[0,1,1,1,0]],
    ':': [[0],[0],[1],[0],[1],[0],[0]],
  };

  @override
  Widget build(BuildContext context) {
    final color = themeColor.color;
    final a = opacityMultiplier;

    final timeStr = timeFormat == TimeFormat.hour12
        ? DateFormat('hh:mm').format(time)
        : DateFormat('HH:mm').format(time);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot matrix grid
        SizedBox(
          height: 56,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int ci = 0; ci < timeStr.length; ci++) ...[
                if (ci > 0) const SizedBox(width: 4),
                _buildChar(timeStr[ci], color, a),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          DateFormat('EEEE, MMM d').format(time),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w300,
            color: color.withValues(alpha: 0.4 * a),
          ),
        ),
      ],
    );
  }

  Widget _buildChar(String ch, Color color, double a) {
    final pattern = _patterns[ch];
    if (pattern == null) return const SizedBox(width: 4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in pattern)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final dot in row)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dot == 1
                        ? color.withValues(alpha: 0.9 * a)
                        : color.withValues(alpha: 0.06 * a),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ZEN CLOCK — Minimal breathing presence
// ═══════════════════════════════════════════════════════

class ZenClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const ZenClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _hour => timeFormat == TimeFormat.hour12
      ? DateFormat('h').format(time)
      : DateFormat('HH').format(time);
  String get _minute => DateFormat('mm').format(time);

  @override
  Widget build(BuildContext context) {
    final color = themeColor.color;
    final a = opacityMultiplier;
    // Breathing: seconds-based opacity pulse for the dot
    final breathe = (sin(time.second * pi / 30) * 0.5 + 0.5); // 0→1→0 over 60s

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _hour,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w100,
                letterSpacing: 2,
                color: color.withValues(alpha: 0.85 * a),
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: breathe * a),
                ),
              ),
            ),
            Text(
              _minute,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w100,
                letterSpacing: 2,
                color: color.withValues(alpha: 0.85 * a),
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TYPEWRITER CLOCK — Monospaced typed-out look
// ═══════════════════════════════════════════════════════

class TypewriterClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const TypewriterClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('hh:mm:ss a').format(time)
      : DateFormat('HH:mm:ss').format(time);
  String get _date => DateFormat('yyyy.MM.dd').format(time);
  String get _day => DateFormat('EEEE').format(time).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final color = themeColor.color;
    final a = opacityMultiplier;
    // Blinking cursor: visible on even seconds
    final cursorVisible = time.second % 2 == 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date line
        Text(
          '> $_date',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
            color: color.withValues(alpha: 0.35 * a),
          ),
        ),
        const SizedBox(height: 4),
        // Day line
        Text(
          '> $_day',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
            color: color.withValues(alpha: 0.35 * a),
          ),
        ),
        const SizedBox(height: 10),
        // Time line with cursor
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '> $_time',
              style: TextStyle(
                fontSize: 32,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w400,
                letterSpacing: 2,
                color: color.withValues(alpha: 0.9 * a),
                height: 1,
              ),
            ),
            AnimatedOpacity(
              opacity: cursorVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.only(left: 2),
                color: color.withValues(alpha: 0.7 * a),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ARC CLOCK — Time curved along a circular path
// ═══════════════════════════════════════════════════════

class ArcClockWidget extends StatelessWidget {
  final DateTime time;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const ArcClockWidget({
    super.key,
    required this.time,
    required this.themeColor,
    required this.timeFormat,
    this.opacityMultiplier = 1.0,
  });

  String get _time => timeFormat == TimeFormat.hour12
      ? DateFormat('h : mm').format(time)
      : DateFormat('HH : mm').format(time);
  String get _period =>
      timeFormat == TimeFormat.hour12 ? DateFormat('a').format(time) : '';

  @override
  Widget build(BuildContext context) {
    final color = themeColor.color;
    final a = opacityMultiplier;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer thin ring
          SizedBox(
            width: 230,
            height: 230,
            child: CustomPaint(
              painter: _ArcRingPainter(
                color: color.withValues(alpha: 0.12 * a),
                strokeWidth: 1,
              ),
            ),
          ),
          // Arc text
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _ArcTextPainter(
                text: _time,
                color: color.withValues(alpha: 0.9 * a),
                fontSize: 40,
              ),
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_period.isNotEmpty)
                Text(
                  _period,
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w300,
                    color: color.withValues(alpha: 0.5 * a),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEE, MMM d').format(time),
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w300,
                  color: color.withValues(alpha: 0.4 * a),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _ArcRingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width / 2 - strokeWidth, paint);
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) => old.color != color;
}

class _ArcTextPainter extends CustomPainter {
  final String text;
  final Color color;
  final double fontSize;
  _ArcTextPainter({required this.text, required this.color, required this.fontSize});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Each character spans an angle — distribute along the top arc
    final totalAngle = text.length * 0.18; // radians per char
    final startAngle = -pi / 2 - totalAngle / 2;

    for (int i = 0; i < text.length; i++) {
      final angle = startAngle + i * 0.18;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w200,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ArcTextPainter old) =>
      old.text != text || old.color != color;
}
