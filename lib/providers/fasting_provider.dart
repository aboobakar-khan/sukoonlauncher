import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../features/prayer_alarm/providers/prayer_alarm_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class FastingTimes {
  final String sahur;   // e.g. "4:04 AM"
  final String iftar;   // e.g. "6:53 PM"
  final String duration;
  final String date;

  const FastingTimes({
    required this.sahur,
    required this.iftar,
    required this.duration,
    required this.date,
  });

  factory FastingTimes.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both nested and flat JSON structures
      final time = json.containsKey('time') 
          ? json['time'] as Map<String, dynamic>
          : json;
      
      return FastingTimes(
        sahur: time['sahur'] as String? ?? '',
        iftar: time['iftar'] as String? ?? '',
        duration: time['duration'] as String? ?? '',
        date: json['date'] as String? ?? time['date'] as String? ?? '',
      );
    } catch (e) {
      // Fallback to empty if parsing fails
      return const FastingTimes(
        sahur: '',
        iftar: '',
        duration: '',
        date: '',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'time': {
      'sahur': sahur,
      'iftar': iftar,
      'duration': duration,
    },
    'date': date,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum FastingStatus { idle, loading, loaded, error }

class FastingState {
  final FastingStatus status;
  final FastingTimes? times;
  final String? errorMessage;
  final String? lastFetchDate; // Track when data was last fetched

  const FastingState({
    this.status = FastingStatus.idle,
    this.times,
    this.errorMessage,
    this.lastFetchDate,
  });

  bool get isLoaded => status == FastingStatus.loaded && times != null;

  FastingState copyWith({
    FastingStatus? status,
    FastingTimes? times,
    String? errorMessage,
    String? lastFetchDate,
  }) {
    return FastingState(
      status: status ?? this.status,
      times: times ?? this.times,
      errorMessage: errorMessage ?? this.errorMessage,
      lastFetchDate: lastFetchDate ?? this.lastFetchDate,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class FastingNotifier extends StateNotifier<FastingState> {
  static const _apiKey = 'Ypx6d5uYlMdT5klzdJeZcOEIF5yelXMzkR4cqvlaO1Sx2wkp';
  static const _cacheKeyData = 'fasting_cached_data';
  static const _cacheKeyDate = 'fasting_cached_date';

  final Ref _ref;

  FastingNotifier(this._ref) : super(const FastingState()) {
    _init();
  }

  Future<void> _init() async {
    // Always try loading from cache first — show it immediately
    final prefs = await SharedPreferences.getInstance();
    final today = _todayStr();
    final cachedDate = prefs.getString(_cacheKeyDate);
    final cachedData = prefs.getString(_cacheKeyData);

    FastingTimes? cachedTimes;
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData) as Map<String, dynamic>;
        cachedTimes = FastingTimes.fromJson(json);
      } catch (_) {
        // Invalid cache — clear it
        await prefs.remove(_cacheKeyData);
        await prefs.remove(_cacheKeyDate);
      }
    }

    // Show cached data immediately (even if stale) so UI never shows empty
    if (cachedTimes != null) {
      state = FastingState(
        status: FastingStatus.loaded,
        times: cachedTimes,
        lastFetchDate: cachedDate,
      );
    }

    // Always fetch fresh data if today's not cached
    if (cachedDate != today) {
      await fetch();
    }
    // If today is cached, we're done — no need to re-fetch
  }

  Future<void> fetch() async {
    final config = _ref.read(prayerAlarmProvider).config;
    if (config.latitude == 0.0 && config.longitude == 0.0) {
      state = const FastingState(
        status: FastingStatus.error,
        errorMessage: 'Location not set',
      );
      return;
    }

    state = state.copyWith(
      status: state.times != null ? FastingStatus.loaded : FastingStatus.loading,
    );

    try {
      final lat = config.latitude;
      final lon = config.longitude;
      final method = config.calculationMethod;

      final uri = Uri.parse(
        'https://islamicapi.com/api/v1/fasting/'
        '?lat=$lat&lon=$lon&api_key=$_apiKey&method=$method',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 200) {
          final fasting =
              (body['data']['fasting'] as List).first as Map<String, dynamic>;
          final times = FastingTimes.fromJson(fasting);

          final today = _todayStr();
          
          // Cache it
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKeyDate, today);
          await prefs.setString(_cacheKeyData, jsonEncode(times.toJson()));

          state = FastingState(
            status: FastingStatus.loaded,
            times: times,
            lastFetchDate: today,
          );
        } else {
          // Keep previously loaded times visible; just mark error silently
          state = state.copyWith(
            status: state.times != null ? FastingStatus.loaded : FastingStatus.error,
            errorMessage: body['message'] as String? ?? 'API error',
          );
        }
      } else {
        // Keep previously loaded times visible; just mark error silently
        state = state.copyWith(
          status: state.times != null ? FastingStatus.loaded : FastingStatus.error,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      // Network error — if we already have times (cached), keep showing them
      if (state.times == null) {
        state = state.copyWith(
          status: FastingStatus.error,
          errorMessage: e.toString(),
        );
      }
      // else: silently swallow — cached data stays visible
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final fastingProvider =
    StateNotifierProvider<FastingNotifier, FastingState>(
  (ref) => FastingNotifier(ref),
);
