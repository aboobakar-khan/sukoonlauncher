import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/fasting_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/display_settings_provider.dart';
import '../features/prayer_alarm/providers/prayer_alarm_provider.dart';

/// Minimal Suhoor / Iftar fasting widget.
/// Uses IslamicAPI for accurate times based on user's saved location.
/// Shows next prayer row + active Suhoor or Iftar countdown.
/// Toggle in Settings → Display → Fasting Times.
///
/// Wrapped in a StatefulWidget with a minute-boundary timer so that
/// countdown strings ("in 2h 30m") update every minute — matching
/// the approach used by PrayerTimeWidget.
class FastingWidget extends ConsumerStatefulWidget {
  const FastingWidget({super.key});

  @override
  ConsumerState<FastingWidget> createState() => _FastingWidgetState();
}

class _FastingWidgetState extends ConsumerState<FastingWidget> {
  Timer? _minuteTimer;
  int _lastMinute = -1;

  @override
  void initState() {
    super.initState();
    _lastMinute = DateTime.now().minute;
    _scheduleNextMinuteTick();
  }

  void _scheduleNextMinuteTick() {
    _minuteTimer?.cancel();
    final now = DateTime.now();
    final secondsUntilNextMinute = 60 - now.second;
    _minuteTimer = Timer(Duration(seconds: secondsUntilNextMinute), _onMinuteTick);
  }

  void _onMinuteTick() {
    if (!mounted) return;
    final currentMinute = DateTime.now().minute;
    if (currentMinute != _lastMinute) {
      _lastMinute = currentMinute;
      setState(() {}); // Rebuild to refresh countdowns
    }
    _scheduleNextMinuteTick();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const _FastingWidgetContent();
  }
}

/// Internal content widget — separated so the timer-driven rebuild
/// only touches this subtree.
class _FastingWidgetContent extends ConsumerWidget {
  const _FastingWidgetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(displaySettingsProvider);
    if (!display.showFastingWidget) return const SizedBox.shrink();

    final accent = ref.watch(themeColorProvider).color;
    final fastingState = ref.watch(fastingProvider);
    final alarmState = ref.watch(prayerAlarmProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1B2A).withValues(alpha: 0.85),
            const Color(0xFF0A1628).withValues(alpha: 0.70),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.15),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildContent(context, ref, accent, fastingState, alarmState),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Color accent,
    FastingState fastingState,
    PrayerAlarmState alarmState,
  ) {
    final nextPrayer = _getNextPrayer(alarmState);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row: icon + "FASTING TIMES" label + refresh ──────────
          Row(
            children: [
              Icon(
                Icons.nightlight_round,
                size: 14,
                color: accent.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 7),
              Text(
                'FASTING TIMES',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              // Retry button on error
              if (fastingState.status == FastingStatus.error)
                GestureDetector(
                  onTap: () => ref.read(fastingProvider.notifier).fetch(),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 11),
          Container(height: 0.4, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 11),

          // ── Next Prayer row ──────────────────────────────────────────────
          if (nextPrayer != null)
            _NextPrayerRow(
              name: nextPrayer['name']!,
              time: nextPrayer['time']!,
              countdown: nextPrayer['countdown']!,
              accent: accent,
            ),

          if (nextPrayer != null) const SizedBox(height: 10),

          // ── Suhoor / Iftar rows ──────────────────────────────────────────
          if (fastingState.status == FastingStatus.loading)
            _LoadingRow(accent: accent)
          else if (fastingState.status == FastingStatus.error)
            _ErrorRow(message: fastingState.errorMessage ?? 'Unavailable')
          else if (fastingState.isLoaded)
            _SuhoorIftarRows(
              times: fastingState.times!,
              accent: accent,
            )
          else
            _ErrorRow(message: 'Fetching times…'),
        ],
      ),
    );
  }

  /// Next upcoming prayer from prayer alarm provider.
  Map<String, String>? _getNextPrayer(PrayerAlarmState alarmState) {
    if (alarmState.todayTimes == null) return null;
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final now = DateTime.now();
    for (final prayer in prayers) {
      final timeStr = alarmState.effectiveTimesMap[prayer];
      if (timeStr == null) continue;
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final target = DateTime(now.year, now.month, now.day, h, m);
      if (target.isAfter(now)) {
        final diff = target.difference(now);
        return {
          'name': prayer,
          'time': DateFormat('h:mm a').format(target),
          'countdown': _formatCountdown(diff),
        };
      }
    }
    return null;
  }

  String _formatCountdown(Duration diff) {
    if (diff.inSeconds < 60) return 'now';
    if (diff.inHours < 1) return 'in ${diff.inMinutes}m';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m > 0 ? 'in ${h}h ${m}m' : 'in ${h}h';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NextPrayerRow extends StatelessWidget {
  final String name;
  final String time;
  final String countdown;
  final Color accent;

  const _NextPrayerRow({
    required this.name,
    required this.time,
    required this.countdown,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.mosque_rounded, size: 13, color: accent.withValues(alpha: 0.5)),
        const SizedBox(width: 7),
        Text(
          'NEXT',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
        const Spacer(),
        Text(
          time,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: accent.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          countdown,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _SuhoorIftarRows extends StatelessWidget {
  final FastingTimes times;
  final Color accent;

  const _SuhoorIftarRows({required this.times, required this.accent});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sahurTime = _parse12h(times.sahur, now);
    final iftarTime = _parse12h(times.iftar, now);

    final activeColor = accent;
    final dimColor = Colors.white.withValues(alpha: 0.22);

    // Determine which is active / approaching
    // Before sahur end → Suhoor is active/approaching
    // After sahur, before iftar → Iftar is next
    // After iftar → both done

    bool isFasting = false;
    bool sahurPassed = false;
    Duration? sahurLeft;
    Duration? iftarLeft;

    if (sahurTime != null) {
      sahurPassed = now.isAfter(sahurTime);
      if (!sahurPassed) sahurLeft = sahurTime.difference(now);
    }
    if (iftarTime != null && sahurPassed) {
      isFasting = now.isBefore(iftarTime);
      if (isFasting) iftarLeft = iftarTime.difference(now);
    }

    return Column(
      children: [
        const SizedBox(height: 2),
        // Suhoor row
        _FastingRow(
          icon: Icons.wb_twilight_rounded,
          label: 'SUHOOR',
          time: times.sahur,
          countdown: sahurLeft != null
              ? _fmt(sahurLeft)
              : (sahurPassed ? 'done' : '—'),
          accentColor: !sahurPassed ? activeColor : dimColor,
          isActive: !sahurPassed,
        ),
        const SizedBox(height: 8),
        // Iftar row
        _FastingRow(
          icon: Icons.nightlight_round,
          label: 'IFTAR',
          time: times.iftar,
          countdown: iftarLeft != null
              ? _fmt(iftarLeft)
              : (isFasting ? '—' : 'done'),
          accentColor: isFasting ? activeColor : dimColor,
          isActive: isFasting,
        ),
      ],
    );
  }

  DateTime? _parse12h(String timeStr, DateTime base) {
    try {
      final dt = DateFormat('h:mm a').parse(timeStr.trim());
      return DateTime(base.year, base.month, base.day, dt.hour, dt.minute);
    } catch (_) {
      return null;
    }
  }

  String _fmt(Duration d) {
    if (d.inSeconds < 60) return 'now';
    if (d.inHours < 1) return 'in ${d.inMinutes}m';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m > 0 ? 'in ${h}h ${m}m' : 'in ${h}h';
  }
}

class _FastingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final String countdown;
  final Color accentColor;
  final bool isActive;

  const _FastingRow({
    required this.icon,
    required this.label,
    required this.time,
    required this.countdown,
    required this.accentColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: accentColor.withValues(alpha: isActive ? 0.65 : 0.35)),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
            color: isActive
                ? accentColor.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
        const Spacer(),
        Text(
          time,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            countdown,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              color: isActive
                  ? accentColor.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingRow extends StatelessWidget {
  final Color accent;
  const _LoadingRow({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: accent.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Loading fasting times…',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        fontSize: 11,
        color: Colors.white.withValues(alpha: 0.25),
      ),
    );
  }
}
