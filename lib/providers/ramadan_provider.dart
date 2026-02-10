import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 🌙 RAMADAN PROVIDER — Core state for Ramadan Mode (Enhanced)
// ═══════════════════════════════════════════════════════════════════════════════

/// Ramadan 2026 dates: Feb 18 – Mar 19 (approximate)
/// Configurable via manual Hive settings for accuracy.

class RamadanState {
  final bool isEnabled;
  final DateTime ramadanStartDate;
  final int totalDays; // 29 or 30

  // Daily checklist (today's state)
  final bool suhoorDone;
  final bool iftarDuaDone;
  final bool taraweehDone;
  final bool extraQuranDone;
  final bool charityDone;

  // Taraweeh detail
  final int taraweehRakats; // 0, 8, or 20

  // Quran Khatm progress
  final int quranPagesReadToday;
  final int quranTotalPagesRead;
  final int dailyQuranGoal; // pages per day

  // Charity
  final double totalCharityAmount;
  final double todayCharityAmount;
  final double charityGoal; // user-set Ramadan charity goal

  // Last 10 nights
  final bool last10NightsMode;

  // Streak tracking
  final int currentStreak; // consecutive perfect days
  final int bestStreak;

  // Prayer times (user configurable)
  final int fajrHour;
  final int fajrMinute;
  final int maghribHour;
  final int maghribMinute;

  // Completed days for weekly dots
  final List<String> completedDays;

  RamadanState({
    this.isEnabled = false,
    DateTime? ramadanStartDate,
    this.totalDays = 30,
    this.suhoorDone = false,
    this.iftarDuaDone = false,
    this.taraweehDone = false,
    this.extraQuranDone = false,
    this.charityDone = false,
    this.taraweehRakats = 0,
    this.quranPagesReadToday = 0,
    this.quranTotalPagesRead = 0,
    this.dailyQuranGoal = 20,
    this.totalCharityAmount = 0.0,
    this.todayCharityAmount = 0.0,
    this.charityGoal = 0.0,
    this.last10NightsMode = false,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.fajrHour = 5,
    this.fajrMinute = 30,
    this.maghribHour = 18,
    this.maghribMinute = 15,
    this.completedDays = const [],
  }) : ramadanStartDate = ramadanStartDate ?? DateTime(2026, 2, 18);

  // Computed properties
  int get currentDay {
    if (!isEnabled) return 0;
    final now = DateTime.now();
    final diff = now.difference(ramadanStartDate).inDays + 1;
    return diff.clamp(1, totalDays);
  }

  bool get isRamadanActive {
    if (!isEnabled) return false;
    final now = DateTime.now();
    final endDate = ramadanStartDate.add(Duration(days: totalDays));
    return now.isAfter(ramadanStartDate.subtract(const Duration(days: 1))) &&
        now.isBefore(endDate.add(const Duration(days: 1)));
  }

  int get daysRemaining => (totalDays - currentDay).clamp(0, totalDays);

  bool get isLast10Nights => currentDay > (totalDays - 10);

  bool get isOddNight {
    final nightNum = totalDays - daysRemaining;
    return nightNum.isOdd;
  }

  double get overallProgress => currentDay / totalDays;

  int get quranJuz => (quranTotalPagesRead / 20).floor().clamp(0, 30);

  double get quranKhatmProgress => quranTotalPagesRead / 604;

  int get pagesRemainingToday =>
      (dailyQuranGoal - quranPagesReadToday).clamp(0, dailyQuranGoal);

  int get adjustedDailyGoal {
    final pagesRemaining = 604 - quranTotalPagesRead;
    if (daysRemaining <= 0) return pagesRemaining;
    return (pagesRemaining / daysRemaining).ceil().clamp(1, 40);
  }

  // ── Fasting time helpers ──
  bool get isFastingTime {
    final now = DateTime.now();
    final fajrToday = DateTime(now.year, now.month, now.day, fajrHour, fajrMinute);
    final maghribToday = DateTime(now.year, now.month, now.day, maghribHour, maghribMinute);
    return now.isAfter(fajrToday) && now.isBefore(maghribToday);
  }

  Duration get fastDuration {
    final fajr = DateTime(2026, 1, 1, fajrHour, fajrMinute);
    final maghrib = DateTime(2026, 1, 1, maghribHour, maghribMinute);
    return maghrib.difference(fajr);
  }

  double get fastingProgress {
    if (!isFastingTime) return 0.0;
    final now = DateTime.now();
    final fajr = DateTime(now.year, now.month, now.day, fajrHour, fajrMinute);
    final elapsed = now.difference(fajr);
    return (elapsed.inMinutes / fastDuration.inMinutes).clamp(0.0, 1.0);
  }

  Duration get timeUntilIftar {
    final now = DateTime.now();
    final maghrib = DateTime(now.year, now.month, now.day, maghribHour, maghribMinute);
    if (now.isAfter(maghrib)) return Duration.zero;
    return maghrib.difference(now);
  }

  Duration get timeUntilSuhoor {
    final now = DateTime.now();
    var fajr = DateTime(now.year, now.month, now.day, fajrHour, fajrMinute);
    if (now.isAfter(fajr)) fajr = fajr.add(const Duration(days: 1));
    return fajr.difference(now);
  }

  int get checklistCompleted {
    int count = 0;
    if (suhoorDone) count++;
    if (iftarDuaDone) count++;
    if (taraweehDone) count++;
    if (quranPagesReadToday >= dailyQuranGoal) count++;
    if (charityDone) count++;
    return count;
  }

  int get checklistTotal => 5;

  bool get isTodayPerfect => checklistCompleted >= checklistTotal;

  // ── Quran pace intelligence ──
  String get quranPaceStatus {
    final expectedPages = (currentDay / totalDays * 604).round();
    final diff = quranTotalPagesRead - expectedPages;
    if (diff >= 10) return 'Ahead of schedule';
    if (diff >= 0) return 'On track';
    if (diff >= -10) return '${-diff} pages behind';
    return 'Needs attention';
  }

  // ── Suhoor & Iftar Duas (actual text) ──
  static const suhoorDuaArabic = 'وَبِصَوْمِ غَدٍ نَّوَيْتُ مِنْ شَهْرِ رَمَضَانَ';
  static const suhoorDuaTranslation = 'I intend to keep the fast for tomorrow in the month of Ramadan.';
  static const iftarDuaArabic = 'اللَّهُمَّ إِنِّي لَكَ صُمْتُ وَبِكَ آمَنْتُ وَعَلَى رِزْقِكَ أَفْطَرْتُ';
  static const iftarDuaTranslation = 'O Allah, I fasted for You, I believed in You, and with Your provision I break my fast.';

  // ── 30 Daily Ramadan Duas ──
  String get dailyDuaArabic => _dailyDuas[(currentDay - 1).clamp(0, 29)]['arabic']!;
  String get dailyDuaTranslation => _dailyDuas[(currentDay - 1).clamp(0, 29)]['translation']!;
  String get dailyDuaReference => _dailyDuas[(currentDay - 1).clamp(0, 29)]['ref']!;
  String get dailyDuaDay => 'Day $currentDay Dua';

  static const List<Map<String, String>> _dailyDuas = [
    {'arabic': 'اللَّهُمَّ اجْعَلْ صِيَامِي فِيهِ صِيَامَ الصَّائِمِينَ', 'translation': 'O Allah, make my fasting the fasting of those who truly fast.', 'ref': 'Day 1'},
    {'arabic': 'اللَّهُمَّ قَرِّبْنِي فِيهِ إِلَى مَرْضَاتِكَ', 'translation': 'O Allah, bring me closer to Your pleasure.', 'ref': 'Day 2'},
    {'arabic': 'اللَّهُمَّ ارْزُقْنِي فِيهِ الذِّهْنَ وَالتَّنْبِيهَ', 'translation': 'O Allah, grant me awareness and alertness.', 'ref': 'Day 3'},
    {'arabic': 'اللَّهُمَّ قَوِّنِي فِيهِ عَلَى إِقَامَةِ أَمْرِكَ', 'translation': 'O Allah, give me strength to fulfill Your commands.', 'ref': 'Day 4'},
    {'arabic': 'اللَّهُمَّ اجْعَلْنِي فِيهِ مِنْ أَهْلِ الاِسْتِغْفَارِ', 'translation': 'O Allah, make me among those who seek forgiveness.', 'ref': 'Day 5'},
    {'arabic': 'اللَّهُمَّ لَا تَخْذُلْنِي فِيهِ لِتَعَرُّضِ مَعْصِيَتِكَ', 'translation': 'O Allah, do not abandon me when I face sin.', 'ref': 'Day 6'},
    {'arabic': 'اللَّهُمَّ أَعِنِّي فِيهِ عَلَى صِيَامِهِ وَقِيَامِهِ', 'translation': 'O Allah, help me fast and pray at night.', 'ref': 'Day 7'},
    {'arabic': 'اللَّهُمَّ ارْزُقْنِي فِيهِ رَحْمَةَ الأَيْتَامِ', 'translation': 'O Allah, grant me compassion for orphans.', 'ref': 'Day 8'},
    {'arabic': 'اللَّهُمَّ اجْعَلْ لِي فِيهِ نَصِيبًا مِنْ رَحْمَتِكَ', 'translation': 'O Allah, allot me a share of Your mercy.', 'ref': 'Day 9'},
    {'arabic': 'اللَّهُمَّ اجْعَلْنِي فِيهِ مِنَ الْمُتَوَكِّلِينَ عَلَيْكَ', 'translation': 'O Allah, make me among those who rely on You.', 'ref': 'Day 10'},
    {'arabic': 'اللَّهُمَّ حَبِّبْ إِلَيَّ فِيهِ الإِحْسَانَ', 'translation': 'O Allah, make me love doing good in this month.', 'ref': 'Day 11'},
    {'arabic': 'اللَّهُمَّ زَيِّنِّي فِيهِ بِالسِّتْرِ وَالْعَفَافِ', 'translation': 'O Allah, adorn me with modesty and virtue.', 'ref': 'Day 12'},
    {'arabic': 'اللَّهُمَّ طَهِّرْنِي فِيهِ مِنَ الدَّنَسِ وَالأَقْذَارِ', 'translation': 'O Allah, purify me from impurities and sins.', 'ref': 'Day 13'},
    {'arabic': 'اللَّهُمَّ لَا تُؤَاخِذْنِي فِيهِ بِالْعَثَرَاتِ', 'translation': 'O Allah, do not hold me accountable for my mistakes.', 'ref': 'Day 14'},
    {'arabic': 'اللَّهُمَّ ارْزُقْنِي فِيهِ طَاعَةَ الْخَاشِعِينَ', 'translation': 'O Allah, grant me the obedience of the humble.', 'ref': 'Day 15'},
    {'arabic': 'اللَّهُمَّ وَفِّقْنِي فِيهِ لِمُرَافَقَةِ الأَبْرَارِ', 'translation': 'O Allah, allow me to accompany the righteous.', 'ref': 'Day 16'},
    {'arabic': 'اللَّهُمَّ اهْدِنِي فِيهِ لِصَالِحِ الأَعْمَالِ', 'translation': 'O Allah, guide me to righteous deeds.', 'ref': 'Day 17'},
    {'arabic': 'اللَّهُمَّ نَبِّهْنِي فِيهِ لِبَرَكَاتِ أَسْحَارِهِ', 'translation': 'O Allah, awaken me to the blessings of Suhoor.', 'ref': 'Day 18'},
    {'arabic': 'اللَّهُمَّ وَفِّرْ حَظِّي فِيهِ مِنْ بَرَكَاتِهِ', 'translation': 'O Allah, increase my share of its blessings.', 'ref': 'Day 19'},
    {'arabic': 'اللَّهُمَّ افْتَحْ لِي فِيهِ أَبْوَابَ الْجِنَانِ', 'translation': 'O Allah, open for me the doors of Paradise.', 'ref': 'Day 20'},
    {'arabic': 'اللَّهُمَّ اجْعَلْ لِي فِيهِ إِلَى مَرْضَاتِكَ دَلِيلًا', 'translation': 'O Allah, guide me to what pleases You.', 'ref': 'Day 21'},
    {'arabic': 'اللَّهُمَّ افْتَحْ لِي فِيهِ أَبْوَابَ فَضْلِكَ', 'translation': 'O Allah, open the doors of Your grace for me.', 'ref': 'Day 22'},
    {'arabic': 'اللَّهُمَّ اغْسِلْنِي فِيهِ مِنَ الذُّنُوبِ', 'translation': 'O Allah, wash me clean of sins.', 'ref': 'Day 23'},
    {'arabic': 'اللَّهُمَّ إِنِّي أَسْأَلُكَ فِيهِ مَا يُرْضِيكَ', 'translation': 'O Allah, I ask You for what pleases You.', 'ref': 'Day 24'},
    {'arabic': 'اللَّهُمَّ اجْعَلْنِي فِيهِ مُحِبًّا لِأَوْلِيَائِكَ', 'translation': 'O Allah, make me love Your close servants.', 'ref': 'Day 25'},
    {'arabic': 'اللَّهُمَّ اجْعَلْ سَعْيِي فِيهِ مَشْكُورًا', 'translation': 'O Allah, make my effort appreciated.', 'ref': 'Day 26'},
    {'arabic': 'اللَّهُمَّ ارْزُقْنِي فِيهِ فَضْلَ لَيْلَةِ الْقَدْرِ', 'translation': 'O Allah, grant me the virtue of Laylatul Qadr.', 'ref': 'Day 27'},
    {'arabic': 'اللَّهُمَّ اجْعَلْنِي فِيهِ مِنَ الْمَقْبُولِينَ', 'translation': 'O Allah, make me among those accepted by You.', 'ref': 'Day 28'},
    {'arabic': 'اللَّهُمَّ غَشِّنِي فِيهِ بِالرَّحْمَةِ', 'translation': 'O Allah, envelop me with mercy.', 'ref': 'Day 29'},
    {'arabic': 'اللَّهُمَّ اجْعَلْ صِيَامِي فِيهِ بِالشُّكْرِ وَالْقَبُولِ', 'translation': 'O Allah, make my fasting accepted with gratitude.', 'ref': 'Day 30'},
  ];

  // ── Motivational hadith (kept as secondary content) ──
  String get dailyHadith {
    const hadiths = [
      '"When Ramadan begins, the gates of Paradise are opened."',
      '"Whoever fasts Ramadan with faith and seeking reward, his past sins will be forgiven."',
      '"There is a gate in Paradise called Ar-Rayyan, through which those who fast will enter."',
      '"The best charity is that given in Ramadan."',
      '"Fasting is a shield; so when one of you is fasting, he should not use foul language."',
      '"Every good deed of the son of Adam is multiplied ten to seven hundred times."',
      '"Whoever feeds a fasting person will have a reward like his."',
      '"The supplication of the fasting person is not turned away."',
      '"Whoever stands in prayer during Laylatul Qadr with faith, his past sins will be forgiven."',
      '"Search for Laylatul Qadr in the odd nights of the last ten days."',
    ];
    return hadiths[currentDay % hadiths.length];
  }

  String get dailyHadithSource {
    const sources = [
      'Sahih Bukhari & Muslim',
      'Sahih Bukhari',
      'Sahih Bukhari',
      'At-Tirmidhi',
      'Sahih Bukhari',
      'Sahih Muslim',
      'At-Tirmidhi',
      'Ahmad',
      'Sahih Bukhari & Muslim',
      'Sahih Bukhari',
    ];
    return sources[currentDay % sources.length];
  }

  RamadanState copyWith({
    bool? isEnabled,
    DateTime? ramadanStartDate,
    int? totalDays,
    bool? suhoorDone,
    bool? iftarDuaDone,
    bool? taraweehDone,
    bool? extraQuranDone,
    bool? charityDone,
    int? taraweehRakats,
    int? quranPagesReadToday,
    int? quranTotalPagesRead,
    int? dailyQuranGoal,
    double? totalCharityAmount,
    double? todayCharityAmount,
    double? charityGoal,
    bool? last10NightsMode,
    int? currentStreak,
    int? bestStreak,
    int? fajrHour,
    int? fajrMinute,
    int? maghribHour,
    int? maghribMinute,
    List<String>? completedDays,
  }) {
    return RamadanState(
      isEnabled: isEnabled ?? this.isEnabled,
      ramadanStartDate: ramadanStartDate ?? this.ramadanStartDate,
      totalDays: totalDays ?? this.totalDays,
      suhoorDone: suhoorDone ?? this.suhoorDone,
      iftarDuaDone: iftarDuaDone ?? this.iftarDuaDone,
      taraweehDone: taraweehDone ?? this.taraweehDone,
      extraQuranDone: extraQuranDone ?? this.extraQuranDone,
      charityDone: charityDone ?? this.charityDone,
      taraweehRakats: taraweehRakats ?? this.taraweehRakats,
      quranPagesReadToday: quranPagesReadToday ?? this.quranPagesReadToday,
      quranTotalPagesRead: quranTotalPagesRead ?? this.quranTotalPagesRead,
      dailyQuranGoal: dailyQuranGoal ?? this.dailyQuranGoal,
      totalCharityAmount: totalCharityAmount ?? this.totalCharityAmount,
      todayCharityAmount: todayCharityAmount ?? this.todayCharityAmount,
      charityGoal: charityGoal ?? this.charityGoal,
      last10NightsMode: last10NightsMode ?? this.last10NightsMode,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      fajrHour: fajrHour ?? this.fajrHour,
      fajrMinute: fajrMinute ?? this.fajrMinute,
      maghribHour: maghribHour ?? this.maghribHour,
      maghribMinute: maghribMinute ?? this.maghribMinute,
      completedDays: completedDays ?? this.completedDays,
    );
  }
}

class RamadanNotifier extends StateNotifier<RamadanState> {
  static const String _boxName = 'ramadan_mode';
  Box? _box;
  String _lastResetDate = '';

  RamadanNotifier() : super(RamadanState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);

    final isEnabled = _box!.get('isEnabled', defaultValue: false) as bool;
    final startMillis = _box!.get('startDate') as int?;
    final totalDays = _box!.get('totalDays', defaultValue: 30) as int;
    final totalPages =
        _box!.get('quranTotalPagesRead', defaultValue: 0) as int;
    final dailyGoal = _box!.get('dailyQuranGoal', defaultValue: 20) as int;
    final totalCharity =
        (_box!.get('totalCharityAmount', defaultValue: 0.0) as num)
            .toDouble();
    final last10 =
        _box!.get('last10NightsMode', defaultValue: false) as bool;
    final streak = _box!.get('currentStreak', defaultValue: 0) as int;
    final best = _box!.get('bestStreak', defaultValue: 0) as int;
    final fH = _box!.get('fajrHour', defaultValue: 5) as int;
    final fM = _box!.get('fajrMinute', defaultValue: 30) as int;
    final mH = _box!.get('maghribHour', defaultValue: 18) as int;
    final mM = _box!.get('maghribMinute', defaultValue: 15) as int;
    final completedRaw =
        _box!.get('completedDays', defaultValue: <String>[]) as List;
    final completedDays = completedRaw.cast<String>().toList();

    final startDate = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis)
        : DateTime(2026, 2, 18);

    state = RamadanState(
      isEnabled: isEnabled,
      ramadanStartDate: startDate,
      totalDays: totalDays,
      quranTotalPagesRead: totalPages,
      dailyQuranGoal: dailyGoal,
      totalCharityAmount: totalCharity,
      last10NightsMode: last10,
      currentStreak: streak,
      bestStreak: best,
      fajrHour: fH,
      fajrMinute: fM,
      maghribHour: mH,
      maghribMinute: mM,
      completedDays: completedDays,
    );

    // Load today's checklist
    _loadDailyChecklist();
  }

  void _loadDailyChecklist() {
    if (_box == null) return;
    final today = _todayKey();
    _lastResetDate = _box!.get('lastResetDate', defaultValue: '') as String;

    // Reset daily items if it's a new day
    if (_lastResetDate != today) {
      // Check if yesterday was perfect → update streak
      if (_lastResetDate.isNotEmpty) {
        final yesterdayPerfect =
            _box!.get('perfect_$_lastResetDate', defaultValue: false) as bool;
        if (yesterdayPerfect) {
          final newStreak = state.currentStreak + 1;
          final newBest =
              newStreak > state.bestStreak ? newStreak : state.bestStreak;
          _box!.put('currentStreak', newStreak);
          _box!.put('bestStreak', newBest);
          state = state.copyWith(currentStreak: newStreak, bestStreak: newBest);
        } else {
          _box!.put('currentStreak', 0);
          state = state.copyWith(currentStreak: 0);
        }
      }

      _box!.put('lastResetDate', today);
      _box!.put('suhoor_$today', false);
      _box!.put('iftarDua_$today', false);
      _box!.put('taraweeh_$today', false);
      _box!.put('extraQuran_$today', false);
      _box!.put('charity_$today', false);
      _box!.put('quranPagesToday_$today', 0);
      _box!.put('charityToday_$today', 0.0);
      _lastResetDate = today;
      state = state.copyWith(
        suhoorDone: false,
        iftarDuaDone: false,
        taraweehDone: false,
        extraQuranDone: false,
        charityDone: false,
        quranPagesReadToday: 0,
        todayCharityAmount: 0.0,
      );
    } else {
      state = state.copyWith(
        suhoorDone: _box!.get('suhoor_$today', defaultValue: false) as bool,
        iftarDuaDone:
            _box!.get('iftarDua_$today', defaultValue: false) as bool,
        taraweehDone:
            _box!.get('taraweeh_$today', defaultValue: false) as bool,
        extraQuranDone:
            _box!.get('extraQuran_$today', defaultValue: false) as bool,
        charityDone:
            _box!.get('charity_$today', defaultValue: false) as bool,
        quranPagesReadToday:
            _box!.get('quranPagesToday_$today', defaultValue: 0) as int,
        todayCharityAmount:
            (_box!.get('charityToday_$today', defaultValue: 0.0) as num)
                .toDouble(),
      );
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Toggle methods ──

  Future<void> _checkAndSavePerfectDay() async {
    if (state.isTodayPerfect) {
      final today = _todayKey();
      await _box?.put('perfect_$today', true);
      if (!state.completedDays.contains(today)) {
        final updated = [...state.completedDays, today];
        await _box?.put('completedDays', updated);
        state = state.copyWith(completedDays: updated);
      }
    }
  }

  Future<void> toggleRamadanMode(bool enabled) async {
    _box ??= await Hive.openBox(_boxName);
    await _box!.put('isEnabled', enabled);
    state = state.copyWith(isEnabled: enabled);
    if (enabled) _loadDailyChecklist();
  }

  Future<void> setStartDate(DateTime date) async {
    _box ??= await Hive.openBox(_boxName);
    await _box!.put('startDate', date.millisecondsSinceEpoch);
    state = state.copyWith(ramadanStartDate: date);
  }

  Future<void> setTotalDays(int days) async {
    _box ??= await Hive.openBox(_boxName);
    await _box!.put('totalDays', days);
    state = state.copyWith(totalDays: days);
  }

  Future<void> setPrayerTimes({
    int? fajrHour,
    int? fajrMinute,
    int? maghribHour,
    int? maghribMinute,
  }) async {
    _box ??= await Hive.openBox(_boxName);
    if (fajrHour != null) await _box!.put('fajrHour', fajrHour);
    if (fajrMinute != null) await _box!.put('fajrMinute', fajrMinute);
    if (maghribHour != null) await _box!.put('maghribHour', maghribHour);
    if (maghribMinute != null) await _box!.put('maghribMinute', maghribMinute);
    state = state.copyWith(
      fajrHour: fajrHour ?? state.fajrHour,
      fajrMinute: fajrMinute ?? state.fajrMinute,
      maghribHour: maghribHour ?? state.maghribHour,
      maghribMinute: maghribMinute ?? state.maghribMinute,
    );
  }

  Future<void> toggleSuhoor() async {
    final today = _todayKey();
    final newVal = !state.suhoorDone;
    await _box?.put('suhoor_$today', newVal);
    state = state.copyWith(suhoorDone: newVal);
    _checkAndSavePerfectDay();
  }

  Future<void> toggleIftarDua() async {
    final today = _todayKey();
    final newVal = !state.iftarDuaDone;
    await _box?.put('iftarDua_$today', newVal);
    state = state.copyWith(iftarDuaDone: newVal);
    _checkAndSavePerfectDay();
  }

  Future<void> toggleTaraweeh() async {
    final today = _todayKey();
    final newVal = !state.taraweehDone;
    await _box?.put('taraweeh_$today', newVal);
    state = state.copyWith(taraweehDone: newVal);
    _checkAndSavePerfectDay();
  }

  Future<void> toggleExtraQuran() async {
    final today = _todayKey();
    final newVal = !state.extraQuranDone;
    await _box?.put('extraQuran_$today', newVal);
    state = state.copyWith(extraQuranDone: newVal);
    _checkAndSavePerfectDay();
  }

  Future<void> toggleCharity() async {
    final today = _todayKey();
    final newVal = !state.charityDone;
    await _box?.put('charity_$today', newVal);
    state = state.copyWith(charityDone: newVal);
    _checkAndSavePerfectDay();
  }

  Future<void> setTaraweehRakats(int rakats) async {
    final today = _todayKey();
    await _box?.put('taraweehRakats_$today', rakats);
    state = state.copyWith(
      taraweehRakats: rakats,
      taraweehDone: rakats > 0,
    );
    if (rakats > 0) {
      await _box?.put('taraweeh_$today', true);
    }
    _checkAndSavePerfectDay();
  }

  Future<void> addQuranPages(int pages) async {
    final today = _todayKey();
    final newToday = state.quranPagesReadToday + pages;
    final newTotal = state.quranTotalPagesRead + pages;
    await _box?.put('quranPagesToday_$today', newToday);
    await _box?.put('quranTotalPagesRead', newTotal);
    state = state.copyWith(
      quranPagesReadToday: newToday,
      quranTotalPagesRead: newTotal,
    );
    _checkAndSavePerfectDay();
  }

  Future<void> addCharity(double amount) async {
    final today = _todayKey();
    final newTotal = state.totalCharityAmount + amount;
    final newToday = state.todayCharityAmount + amount;
    await _box?.put('totalCharityAmount', newTotal);
    await _box?.put('charityToday_$today', newToday);
    state = state.copyWith(
      totalCharityAmount: newTotal,
      todayCharityAmount: newToday,
    );
  }

  Future<void> setCharityGoal(double goal) async {
    await _box?.put('charityGoal', goal);
    state = state.copyWith(charityGoal: goal);
  }

  Future<void> toggleLast10NightsMode(bool enabled) async {
    await _box?.put('last10NightsMode', enabled);
    state = state.copyWith(last10NightsMode: enabled);
  }
}

final ramadanProvider =
    StateNotifierProvider<RamadanNotifier, RamadanState>((ref) {
  return RamadanNotifier();
});

/// Convenience provider for quick isEnabled check
final isRamadanModeProvider = Provider<bool>((ref) {
  return ref.watch(ramadanProvider).isEnabled;
});
