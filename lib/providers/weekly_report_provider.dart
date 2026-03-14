import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'prayer_provider.dart';
import 'tasbih_provider.dart';
import 'ramadan_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Weekly Spiritual Report — aggregates data from all providers
// ─────────────────────────────────────────────────────────────────────────────

class WeeklyReport {
  final DateTime weekStart;
  final DateTime weekEnd;

  // Prayer data
  final int totalPrayers;       // out of 35 (7 days × 5)
  final int fajrCount;
  final int dhuhrCount;
  final int asrCount;
  final int maghribCount;
  final int ishaCount;

  // Dhikr data
  final int totalDhikr;
  final int dhikrDays;          // days with at least 1 count

  // Ramadan data (if applicable)
  final int taraweehNightsThisWeek;
  final int fastingDaysThisWeek;
  final int juzCompletedThisWeek;
  final bool isRamadanWeek;

  // Overall
  final double prayerPercentage;
  final String spiritualLevel;
  final String motivationalMessage;

  const WeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    this.totalPrayers = 0,
    this.fajrCount = 0,
    this.dhuhrCount = 0,
    this.asrCount = 0,
    this.maghribCount = 0,
    this.ishaCount = 0,
    this.totalDhikr = 0,
    this.dhikrDays = 0,
    this.taraweehNightsThisWeek = 0,
    this.fastingDaysThisWeek = 0,
    this.juzCompletedThisWeek = 0,
    this.isRamadanWeek = false,
    this.prayerPercentage = 0,
    this.spiritualLevel = '',
    this.motivationalMessage = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Family provider — pass weekOffset (0 = current, -1 = last week, etc.)
// ─────────────────────────────────────────────────────────────────────────────

/// Provider for week offset selection (0 = this week, negative = past weeks)
final weekOffsetProvider = StateProvider<int>((ref) => 0);

/// Family provider: build a report for any week offset
final weeklyReportForOffsetProvider =
    Provider.family<WeeklyReport, int>((ref, weekOffset) {
  return _buildReport(ref, weekOffset);
});

/// Convenience provider for the current week (kept for backward compat)
final weeklyReportProvider = Provider<WeeklyReport>((ref) {
  return _buildReport(ref, 0);
});

WeeklyReport _buildReport(Ref ref, int weekOffset) {
  final now = DateTime.now();
  // Week starts on Saturday (Islamic week)
  final weekday = now.weekday; // 1=Mon … 7=Sun
  final daysSinceSat = (weekday + 1) % 7; // Sat=0, Sun=1, Mon=2 ...
  final thisWeekStart = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysSinceSat));

  // Offset by N weeks
  final weekStart =
      thisWeekStart.add(Duration(days: weekOffset * 7));
  final weekEnd = weekStart.add(const Duration(days: 6));

  // ── Prayer data ──
  final records = ref.watch(prayerRecordListProvider);
  int totalPrayers = 0;
  int fajr = 0, dhuhr = 0, asr = 0, maghrib = 0, isha = 0;

  for (final record in records) {
    final d = record.date;
    if (d.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        d.isBefore(weekEnd.add(const Duration(days: 1)))) {
      if (record.fajr) { fajr++; totalPrayers++; }
      if (record.dhuhr) { dhuhr++; totalPrayers++; }
      if (record.asr) { asr++; totalPrayers++; }
      if (record.maghrib) { maghrib++; totalPrayers++; }
      if (record.isha) { isha++; totalPrayers++; }
    }
  }

  // ── Dhikr data ──
  final tasbih = ref.watch(tasbihProvider);
  int totalDhikr = 0;
  int dhikrDays = 0;
  for (final entry in tasbih.dailyHistory.entries) {
    try {
      final date = DateTime.parse(entry.key);
      if (date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          date.isBefore(weekEnd.add(const Duration(days: 1)))) {
        totalDhikr += entry.value;
        if (entry.value > 0) dhikrDays++;
      }
    } catch (_) {}
  }

  // ── Ramadan data ──
  final ramadan = ref.watch(ramadanProvider);
  int taraweehThisWeek = 0;
  int fastingThisWeek = 0;
  if (ramadan.isRamadan) {
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final night = day.difference(ramadan.ramadanStart).inDays + 1;
      if (night >= 1 && night <= 30) {
        if (ramadan.taraweehNights.contains(night)) taraweehThisWeek++;
        if (ramadan.fastingDays.contains(night)) fastingThisWeek++;
      }
    }
  }

  // ── Spiritual level ──
  final prayerPct = totalPrayers / 35;
  String level;
  String message;
  if (prayerPct >= 0.9) {
    level = 'Excellent';
    message = 'MashaAllah! Keep up the beautiful consistency 🌟';
  } else if (prayerPct >= 0.7) {
    level = 'Good';
    message = "You're doing well — a little more consistency and you'll be at your best 💪";
  } else if (prayerPct >= 0.4) {
    level = 'Growing';
    message = 'Every prayer counts. Keep building the habit, one salah at a time 🤲';
  } else if (prayerPct > 0) {
    level = 'Beginning';
    message = "The journey of a thousand miles starts with a single step. You've started 🌱";
  } else {
    level = 'Fresh Start';
    message = 'This week is a clean slate. Start with just one prayer today 🕊️';
  }

  return WeeklyReport(
    weekStart: weekStart,
    weekEnd: weekEnd,
    totalPrayers: totalPrayers,
    fajrCount: fajr,
    dhuhrCount: dhuhr,
    asrCount: asr,
    maghribCount: maghrib,
    ishaCount: isha,
    totalDhikr: totalDhikr,
    dhikrDays: dhikrDays,
    taraweehNightsThisWeek: taraweehThisWeek,
    fastingDaysThisWeek: fastingThisWeek,
    juzCompletedThisWeek: ramadan.completedJuz.length,
    isRamadanWeek: ramadan.isRamadan,
    prayerPercentage: prayerPct,
    spiritualLevel: level,
    motivationalMessage: message,
  );
}

