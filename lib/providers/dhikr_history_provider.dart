import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'tasbih_provider.dart';
import '../utils/hive_box_manager.dart';

/// Represents a single dhikr session
class DhikrSession {
  final DateTime timestamp;
  final int dhikrIndex;
  final int count;
  final String dhikrName;
  final String arabicText;

  DhikrSession({
    required this.timestamp,
    required this.dhikrIndex,
    required this.count,
    required this.dhikrName,
    required this.arabicText,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'dhikrIndex': dhikrIndex,
    'count': count,
    'dhikrName': dhikrName,
    'arabicText': arabicText,
  };

  factory DhikrSession.fromJson(Map<String, dynamic> json) {
    return DhikrSession(
      timestamp: DateTime.parse(json['timestamp'] as String),
      dhikrIndex: json['dhikrIndex'] as int? ?? 0,
      count: json['count'] as int? ?? 0,
      dhikrName: json['dhikrName'] as String? ?? '',
      arabicText: json['arabicText'] as String? ?? '',
    );
  }

  /// Get time period label (Today, Yesterday, This Week, etc.)
  String get periodLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(sessionDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    if (diff < 30) return 'This Month';
    return 'Earlier';
  }

  /// Get formatted time
  String get formattedTime {
    final hour = timestamp.hour;
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$hour12:$minute $period';
  }
}

/// Daily summary for activity grid
class DailySummary {
  final DateTime date;
  final int totalCount;
  final Map<int, int> dhikrBreakdown;

  DailySummary({
    required this.date,
    required this.totalCount,
    required this.dhikrBreakdown,
  });

  /// Get intensity level (0-4) for activity grid
  int get intensity {
    if (totalCount == 0) return 0;
    if (totalCount < 33) return 1;
    if (totalCount < 100) return 2;
    if (totalCount < 200) return 3;
    return 4;
  }
}

/// Dhikr history state
class DhikrHistoryState {
  final List<DhikrSession> sessions;
  final Map<int, int> allTimeByDhikr;
  final int longestStreak;
  final int totalSessions;

  DhikrHistoryState({
    this.sessions = const [],
    this.allTimeByDhikr = const {},
    this.longestStreak = 0,
    this.totalSessions = 0,
  });

  /// Get total all-time count
  int get totalAllTime => allTimeByDhikr.values.fold(0, (a, b) => a + b);

  /// Get sessions grouped by period
  Map<String, List<DhikrSession>> get groupedSessions {
    final grouped = <String, List<DhikrSession>>{};
    for (final session in sessions) {
      final period = session.periodLabel;
      grouped.putIfAbsent(period, () => []).add(session);
    }
    return grouped;
  }

  /// Get daily summaries for the last N days
  List<DailySummary> getDailySummaries(int days) {
    final now = DateTime.now();
    final summaries = <DailySummary>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final daySessions = sessions.where((s) {
        final sDate = DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day);
        return sDate.isAtSameMomentAs(date);
      });

      final breakdown = <int, int>{};
      int total = 0;
      for (final s in daySessions) {
        breakdown[s.dhikrIndex] = (breakdown[s.dhikrIndex] ?? 0) + s.count;
        total += s.count;
      }

      summaries.add(DailySummary(
        date: date,
        totalCount: total,
        dhikrBreakdown: breakdown,
      ));
    }

    return summaries;
  }

  /// Get top dhikr types by count
  List<MapEntry<int, int>> get topDhikrTypes {
    final entries = allTimeByDhikr.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  DhikrHistoryState copyWith({
    List<DhikrSession>? sessions,
    Map<int, int>? allTimeByDhikr,
    int? longestStreak,
    int? totalSessions,
  }) {
    return DhikrHistoryState(
      sessions: sessions ?? this.sessions,
      allTimeByDhikr: allTimeByDhikr ?? this.allTimeByDhikr,
      longestStreak: longestStreak ?? this.longestStreak,
      totalSessions: totalSessions ?? this.totalSessions,
    );
  }
}

/// Dhikr history notifier
class DhikrHistoryNotifier extends StateNotifier<DhikrHistoryState> {
  static const String _boxName = 'dhikr_history';
  static const String _sessionsKey = 'sessions';
  static const String _allTimeKey = 'all_time_by_dhikr';
  static const String _longestStreakKey = 'longest_streak';
  static const int _maxSessions = 500; // Keep last 500 sessions

  Box<String>? _box;

  DhikrHistoryNotifier() : super(DhikrHistoryState()) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    _load();
  }

  void _load() {
    try {
      // Load sessions
      final sessionsJson = _box?.get(_sessionsKey);
      List<DhikrSession> sessions = [];
      if (sessionsJson != null) {
        final list = jsonDecode(sessionsJson) as List<dynamic>;
        sessions = list.map((j) => DhikrSession.fromJson(j as Map<String, dynamic>)).toList();
      }

      // Load all-time by dhikr
      final allTimeJson = _box?.get(_allTimeKey);
      Map<int, int> allTimeByDhikr = {};
      if (allTimeJson != null) {
        final map = jsonDecode(allTimeJson) as Map<String, dynamic>;
        allTimeByDhikr = map.map((k, v) => MapEntry(int.parse(k), v as int));
      }

      // Load longest streak
      final longestStreak = int.tryParse(_box?.get(_longestStreakKey) ?? '0') ?? 0;

      state = DhikrHistoryState(
        sessions: sessions,
        allTimeByDhikr: allTimeByDhikr,
        longestStreak: longestStreak,
        totalSessions: sessions.length,
      );
    } catch (e) {
      // Use defaults
    }
  }

  Future<void> _save() async {
    await _box?.put(_sessionsKey, jsonEncode(state.sessions.map((s) => s.toJson()).toList()));
    await _box?.put(_allTimeKey, jsonEncode(state.allTimeByDhikr.map((k, v) => MapEntry(k.toString(), v))));
    await _box?.put(_longestStreakKey, state.longestStreak.toString());
  }

  /// Record a completed dhikr session
  void recordSession({
    required int dhikrIndex,
    required int count,
  }) {
    if (count <= 0) return;

    final dhikr = Dhikr.presets[dhikrIndex];
    final session = DhikrSession(
      timestamp: DateTime.now(),
      dhikrIndex: dhikrIndex,
      count: count,
      dhikrName: dhikr.transliteration,
      arabicText: dhikr.arabic,
    );

    // Add session (keep only last N)
    final sessions = [session, ...state.sessions];
    if (sessions.length > _maxSessions) {
      sessions.removeRange(_maxSessions, sessions.length);
    }

    // Update all-time by dhikr
    final allTimeByDhikr = Map<int, int>.from(state.allTimeByDhikr);
    allTimeByDhikr[dhikrIndex] = (allTimeByDhikr[dhikrIndex] ?? 0) + count;

    state = state.copyWith(
      sessions: sessions,
      allTimeByDhikr: allTimeByDhikr,
      totalSessions: sessions.length,
    );
    _save();
  }

  /// Update longest streak (called from tasbih provider)
  void updateLongestStreak(int currentStreak) {
    if (currentStreak > state.longestStreak) {
      state = state.copyWith(longestStreak: currentStreak);
      _save();
    }
  }

  /// Get count for a specific dhikr type
  int getCountForDhikr(int index) {
    return state.allTimeByDhikr[index] ?? 0;
  }

  /// Clear all history
  Future<void> clearHistory() async {
    state = DhikrHistoryState();
    await _box?.clear();
  }
}

/// Provider for dhikr history
final dhikrHistoryProvider = StateNotifierProvider<DhikrHistoryNotifier, DhikrHistoryState>((ref) {
  return DhikrHistoryNotifier();
});
