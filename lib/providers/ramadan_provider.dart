import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ramadan State & Provider
// ─────────────────────────────────────────────────────────────────────────────

class RamadanState {
  final int currentNight;         // 1–30
  final int totalNights;          // 30
  final Set<int> taraweehNights;  // Which nights taraweeh was prayed
  final Set<int> fastingDays;     // Which days (1–30) the fast was kept
  final Set<int> completedJuz;    // Quran Juz completed (1–30)
  final DateTime ramadanStart;    // First day of Ramadan
  final DateTime ramadanEnd;      // Last day of Ramadan
  final bool isRamadan;           // Are we in Ramadan right now?

  const RamadanState({
    this.currentNight = 0,
    this.totalNights = 30,
    this.taraweehNights = const {},
    this.fastingDays = const {},
    this.completedJuz = const {},
    required this.ramadanStart,
    required this.ramadanEnd,
    this.isRamadan = false,
  });

  double get ramadanProgress => totalNights > 0 ? currentNight / totalNights : 0;
  double get khatmProgress => completedJuz.length / 30;
  int get taraweehCount => taraweehNights.length;
  int get fastingCount => fastingDays.length;
  bool get isTaraweehTonight => taraweehNights.contains(currentNight);
  bool get isFastingToday => fastingDays.contains(currentNight);
  bool get isLastTenNights => currentNight >= 21;

  /// Week number (1–5) for a given Ramadan night
  int weekForNight(int night) => ((night - 1) ~/ 7) + 1;

  /// Total weeks in Ramadan
  int get totalWeeks => ((totalNights - 1) ~/ 7) + 1;

  /// Start/end nights for a given week (1-indexed)
  (int, int) weekRange(int week) {
    final start = (week - 1) * 7 + 1;
    final end = (start + 6).clamp(1, totalNights);
    return (start, end);
  }

  /// Taraweeh nights for a given week
  Set<int> taraweehForWeek(int week) {
    final (start, end) = weekRange(week);
    return taraweehNights.where((n) => n >= start && n <= end).toSet();
  }

  /// Fasting days for a given week
  Set<int> fastingForWeek(int week) {
    final (start, end) = weekRange(week);
    return fastingDays.where((n) => n >= start && n <= end).toSet();
  }

  /// Current week number
  int get currentWeek => currentNight > 0 ? weekForNight(currentNight) : 1;

  /// Odd nights in the last 10 — Laylatul Qadr candidates
  List<int> get laylatulQadrNights => const [21, 23, 25, 27, 29];
  int? get nextQadrNight {
    for (final n in laylatulQadrNights) {
      if (n >= currentNight) return n;
    }
    return null;
  }

  RamadanState copyWith({
    int? currentNight,
    int? totalNights,
    Set<int>? taraweehNights,
    Set<int>? fastingDays,
    Set<int>? completedJuz,
    DateTime? ramadanStart,
    DateTime? ramadanEnd,
    bool? isRamadan,
  }) {
    return RamadanState(
      currentNight: currentNight ?? this.currentNight,
      totalNights: totalNights ?? this.totalNights,
      taraweehNights: taraweehNights ?? this.taraweehNights,
      fastingDays: fastingDays ?? this.fastingDays,
      completedJuz: completedJuz ?? this.completedJuz,
      ramadanStart: ramadanStart ?? this.ramadanStart,
      ramadanEnd: ramadanEnd ?? this.ramadanEnd,
      isRamadan: isRamadan ?? this.isRamadan,
    );
  }
}

class RamadanNotifier extends StateNotifier<RamadanState> {
  RamadanNotifier() : super(RamadanState(
    ramadanStart: DateTime(2026, 2, 17),  // Ramadan 2026 approx start
    ramadanEnd: DateTime(2026, 3, 19),    // Ramadan 2026 approx end
  )) {
    _init();
  }

  static const _prefsKey = 'ramadan_data_2026';

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    
    // Calculate current night
    final now = DateTime.now();
    final start = state.ramadanStart;
    final end = state.ramadanEnd;
    final isRamadan = !now.isBefore(start) && !now.isAfter(end);
    final night = isRamadan ? now.difference(start).inDays + 1 : 0;

    if (json != null) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final taraweeh = (data['taraweeh'] as List?)?.map((e) => e as int).toSet() ?? {};
        final fasting = (data['fasting'] as List?)?.map((e) => e as int).toSet() ?? {};
        final juz = (data['juz'] as List?)?.map((e) => e as int).toSet() ?? {};
        state = state.copyWith(
          currentNight: night.clamp(0, 30),
          isRamadan: isRamadan,
          taraweehNights: taraweeh,
          fastingDays: fasting,
          completedJuz: juz,
        );
      } catch (_) {
        state = state.copyWith(currentNight: night.clamp(0, 30), isRamadan: isRamadan);
      }
    } else {
      state = state.copyWith(currentNight: night.clamp(0, 30), isRamadan: isRamadan);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode({
      'taraweeh': state.taraweehNights.toList(),
      'fasting': state.fastingDays.toList(),
      'juz': state.completedJuz.toList(),
    }));
  }

  void toggleTaraweeh() {
    final night = state.currentNight;
    if (night <= 0) return;
    final updated = Set<int>.from(state.taraweehNights);
    if (updated.contains(night)) {
      updated.remove(night);
    } else {
      updated.add(night);
    }
    state = state.copyWith(taraweehNights: updated);
    _save();
  }

  void toggleTaraweehForNight(int night) {
    if (night <= 0 || night > 30) return;
    final updated = Set<int>.from(state.taraweehNights);
    if (updated.contains(night)) {
      updated.remove(night);
    } else {
      updated.add(night);
    }
    state = state.copyWith(taraweehNights: updated);
    _save();
  }

  void toggleFasting() {
    final day = state.currentNight;
    if (day <= 0) return;
    final updated = Set<int>.from(state.fastingDays);
    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      updated.add(day);
    }
    state = state.copyWith(fastingDays: updated);
    _save();
  }

  void toggleFastingForDay(int day) {
    if (day <= 0 || day > 30) return;
    final updated = Set<int>.from(state.fastingDays);
    if (updated.contains(day)) {
      updated.remove(day);
    } else {
      updated.add(day);
    }
    state = state.copyWith(fastingDays: updated);
    _save();
  }

  void toggleJuz(int juz) {
    if (juz < 1 || juz > 30) return;
    final updated = Set<int>.from(state.completedJuz);
    if (updated.contains(juz)) {
      updated.remove(juz);
    } else {
      updated.add(juz);
    }
    state = state.copyWith(completedJuz: updated);
    _save();
  }

  /// Update Ramadan dates (can be adjusted from settings)
  void updateDates(DateTime start, DateTime end) {
    final now = DateTime.now();
    final isRamadan = !now.isBefore(start) && !now.isAfter(end);
    final night = isRamadan ? now.difference(start).inDays + 1 : 0;
    state = state.copyWith(
      ramadanStart: start,
      ramadanEnd: end,
      currentNight: night.clamp(0, 30),
      isRamadan: isRamadan,
    );
  }
}

final ramadanProvider = StateNotifierProvider<RamadanNotifier, RamadanState>((ref) {
  return RamadanNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// Rotating Ramadan Hadith
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, String>> ramadanHadith = [
  {'text': 'When Ramadan begins, the gates of Paradise are opened.', 'source': 'Bukhari'},
  {'text': 'Whoever fasts Ramadan with faith and seeking reward, his past sins are forgiven.', 'source': 'Bukhari'},
  {'text': 'Fasting is a shield; it protects you from the Hellfire.', 'source': 'Ahmad'},
  {'text': 'The supplication of the fasting person is not turned away.', 'source': 'Ibn Majah'},
  {'text': 'Whoever prays during Laylatul Qadr with faith, his past sins are forgiven.', 'source': 'Bukhari'},
  {'text': 'Search for Laylatul Qadr in the odd nights of the last ten.', 'source': 'Bukhari'},
  {'text': 'There is a gate in Paradise called Ar-Rayyan, through which those who fast will enter.', 'source': 'Bukhari'},
  {'text': 'The breath of a fasting person is sweeter to Allah than musk.', 'source': 'Bukhari'},
  {'text': 'Whoever feeds a fasting person will have a reward equal to his.', 'source': 'Tirmidhi'},
  {'text': 'Ramadan is the month whose beginning is mercy, middle is forgiveness, end is freedom from fire.', 'source': 'Ibn Khuzaymah'},
  {'text': 'The best charity is that given in Ramadan.', 'source': 'Tirmidhi'},
  {'text': 'Whoever does not give up false speech, Allah has no need for him to give up food and drink.', 'source': 'Bukhari'},
  {'text': 'Fasting and the Quran will intercede for the servant on the Day of Judgment.', 'source': 'Ahmad'},
  {'text': 'The five daily prayers and Ramadan to Ramadan are expiation for what is between them.', 'source': 'Muslim'},
  {'text': 'When one of you is fasting, let him not behave improperly. If someone fights him, let him say: I am fasting.', 'source': 'Bukhari'},
  {'text': 'Allah said: Every deed of the son of Adam is for him except fasting — it is for Me.', 'source': 'Bukhari'},
  {'text': 'The fasting person has two moments of joy: when he breaks his fast and when he meets his Lord.', 'source': 'Bukhari'},
  {'text': 'Perform Umrah in Ramadan, for it equals a Hajj in reward.', 'source': 'Bukhari'},
  {'text': 'Whoever stands in prayer on Laylatul Qadr, it is better than a thousand months.', 'source': 'Quran 97:3'},
  {'text': 'Whoever prays Taraweeh with the imam until he finishes, it is recorded as if he prayed the whole night.', 'source': 'Abu Dawud'},
  {'text': 'Make dua at the time of breaking fast, for it is answered.', 'source': 'Ibn Majah'},
  {'text': 'Hasten to break the fast, for in that is blessing.', 'source': 'Bukhari'},
  {'text': 'Eat sahur, for in sahur there is barakah.', 'source': 'Bukhari'},
  {'text': 'Do not fast a day or two before Ramadan unless it is a day one usually fasts.', 'source': 'Bukhari'},
  {'text': 'The Quran was revealed in Ramadan as a guidance for mankind.', 'source': 'Quran 2:185'},
  {'text': 'He who gives iftar to a fasting person shall have his sins forgiven.', 'source': 'Ibn Khuzaymah'},
  {'text': 'This month has come to you, and in it is a night better than a thousand months.', 'source': 'Nasa\'i'},
  {'text': 'Tie your provision with fasting; there is no equivalent for it.', 'source': 'Nasa\'i'},
  {'text': 'O Allah, You are Pardoning, You love to pardon, so pardon me.', 'source': 'Tirmidhi'},
  {'text': 'Charity extinguishes sins as water extinguishes fire.', 'source': 'Tirmidhi'},
];
