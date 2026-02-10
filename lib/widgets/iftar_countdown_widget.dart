import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ramadan_provider.dart';

/// 🌙 Iftar Countdown Widget — Subtle overlay on the home clock screen
/// Shows countdown + Ramadan day number below the main clock
class IftarCountdownWidget extends ConsumerStatefulWidget {
  const IftarCountdownWidget({super.key});

  @override
  ConsumerState<IftarCountdownWidget> createState() =>
      _IftarCountdownWidgetState();
}

class _IftarCountdownWidgetState
    extends ConsumerState<IftarCountdownWidget> {
  Timer? _timer;
  Duration _countdown = Duration.zero;
  bool _isFastingTime = true;

  // Approximate prayer times (can be enhanced with location-based API later)
  final TimeOfDay _fajrTime = const TimeOfDay(hour: 5, minute: 30);
  final TimeOfDay _maghribTime = const TimeOfDay(hour: 18, minute: 15);

  static const _moonGold = Color(0xFFC9A84C);
  static const _warmCream = Color(0xFFF5E6C8);

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final todayFajr = DateTime(
        now.year, now.month, now.day, _fajrTime.hour, _fajrTime.minute);
    final todayMaghrib = DateTime(
        now.year, now.month, now.day, _maghribTime.hour, _maghribTime.minute);

    final nextMaghrib = now.isBefore(todayMaghrib)
        ? todayMaghrib
        : todayMaghrib.add(const Duration(days: 1));
    final nextFajr = now.isBefore(todayFajr)
        ? todayFajr
        : todayFajr.add(const Duration(days: 1));

    setState(() {
      _isFastingTime =
          now.isAfter(todayFajr) && now.isBefore(todayMaghrib);
      _countdown = _isFastingTime
          ? nextMaghrib.difference(now)
          : nextFajr.difference(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ramadan = ref.watch(ramadanProvider);
    if (!ramadan.isEnabled) return const SizedBox.shrink();

    final hours = _countdown.inHours;
    final minutes = _countdown.inMinutes % 60;
    final label = _isFastingTime ? 'until Iftar' : 'until Suhoor';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _moonGold.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crescent + Day
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('☪',
                  style: TextStyle(
                      fontSize: 12,
                      color: _moonGold.withValues(alpha: 0.6))),
              const SizedBox(width: 6),
              Text(
                'Day ${ramadan.currentDay}',
                style: TextStyle(
                  color: _moonGold.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Countdown
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${hours}h ${minutes}m',
                style: TextStyle(
                  color: _warmCream.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: _warmCream.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
