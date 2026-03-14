import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../utils/hive_box_manager.dart';
import '../services/alquran_api_service.dart';

// ─────────────────────────────────────────────
// Quran Settings Provider
// Persists: language, reciter, translation on/off
// ─────────────────────────────────────────────

/// Quran settings state
class QuranSettings {
  final String translationLang;   // language code e.g. "en", "ur", "bn"
  final String translationName;   // display name e.g. "English"
  final bool showTranslation;     // toggle translation on/off
  final String selectedReciterKey;     // reciter key from API ("1", "2", "3", "4")
  final String selectedReciterName;    // display name e.g. "Mishary Rashid Al-Afasy"

  const QuranSettings({
    this.translationLang = 'en',
    this.translationName = 'English',
    this.showTranslation = true,
    this.selectedReciterKey = '1',
    this.selectedReciterName = 'Mishary Rashid Al-Afasy',
  });

  QuranSettings copyWith({
    String? translationLang,
    String? translationName,
    bool? showTranslation,
    String? selectedReciterKey,
    String? selectedReciterName,
  }) {
    return QuranSettings(
      translationLang: translationLang ?? this.translationLang,
      translationName: translationName ?? this.translationName,
      showTranslation: showTranslation ?? this.showTranslation,
      selectedReciterKey: selectedReciterKey ?? this.selectedReciterKey,
      selectedReciterName: selectedReciterName ?? this.selectedReciterName,
    );
  }

  Map<String, dynamic> toJson() => {
        'translationLang': translationLang,
        'translationName': translationName,
        'showTranslation': showTranslation,
        'selectedReciterKey': selectedReciterKey,
        'selectedReciterName': selectedReciterName,
      };

  factory QuranSettings.fromJson(Map<String, dynamic> json) {
    return QuranSettings(
      translationLang: json['translationLang'] as String? ?? 'en',
      translationName: json['translationName'] as String? ?? 'English',
      showTranslation: json['showTranslation'] as bool? ?? true,
      selectedReciterKey: json['selectedReciterKey'] as String? ?? '1',
      selectedReciterName: json['selectedReciterName'] as String? ?? 'Mishary Rashid Al-Afasy',
    );
  }
}

/// Provider for Quran settings
final quranSettingsProvider =
    StateNotifierProvider<QuranSettingsNotifier, QuranSettings>((ref) {
  return QuranSettingsNotifier();
});

class QuranSettingsNotifier extends StateNotifier<QuranSettings> {
  static const String _boxName = 'quran_settings';
  static const String _key = 'settings';
  Box<String>? _box;

  QuranSettingsNotifier() : super(const QuranSettings()) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    final saved = _box?.get(_key);
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        state = QuranSettings.fromJson(json);
      } catch (e) {
        debugPrint('QuranSettingsNotifier: Failed to load settings: $e');
      }
    }
  }

  Future<void> _save() async {
    _box ??= await HiveBoxManager.get<String>(_boxName);
    await _box?.put(_key, jsonEncode(state.toJson()));
  }

  Future<void> setTranslationLanguage(String code, String name) async {
    state = state.copyWith(translationLang: code, translationName: name);
    await _save();
  }

  Future<void> setShowTranslation(bool show) async {
    state = state.copyWith(showTranslation: show);
    await _save();
  }

  Future<void> setReciter(String key, String name) async {
    state = state.copyWith(selectedReciterKey: key, selectedReciterName: name);
    await _save();
  }
}

// ─────────────────────────────────────────────
// Available Languages Provider
// ─────────────────────────────────────────────

final alQuranApiServiceProvider = Provider((ref) => AlQuranApiService());

final quranLanguagesProvider = FutureProvider<List<QuranLanguage>>((ref) async {
  final service = ref.read(alQuranApiServiceProvider);
  return await service.getAvailableLanguages();
});

// ─────────────────────────────────────────────
// Translation Download State
// ─────────────────────────────────────────────

class TranslationDownloadState {
  final bool isDownloading;
  final int completed;
  final int total;
  final String? error;
  final Map<String, int> downloadedCounts; // lang -> count

  const TranslationDownloadState({
    this.isDownloading = false,
    this.completed = 0,
    this.total = 114,
    this.error,
    this.downloadedCounts = const {},
  });

  TranslationDownloadState copyWith({
    bool? isDownloading,
    int? completed,
    int? total,
    String? error,
    Map<String, int>? downloadedCounts,
  }) {
    return TranslationDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      error: error,
      downloadedCounts: downloadedCounts ?? this.downloadedCounts,
    );
  }

  double get progress => total > 0 ? completed / total : 0.0;
}

final translationDownloadProvider =
    StateNotifierProvider<TranslationDownloadNotifier, TranslationDownloadState>(
        (ref) {
  return TranslationDownloadNotifier(ref);
});

class TranslationDownloadNotifier extends StateNotifier<TranslationDownloadState> {
  final Ref _ref;

  TranslationDownloadNotifier(this._ref) : super(const TranslationDownloadState()) {
    _loadDownloadedCounts();
  }

  Future<void> _loadDownloadedCounts() async {
    final service = _ref.read(alQuranApiServiceProvider);
    final langs = QuranLanguage.fallbackLanguages;
    final counts = <String, int>{};
    for (final lang in langs) {
      counts[lang.code] = await service.getDownloadedCount(lang.code);
    }
    state = state.copyWith(downloadedCounts: counts);
  }

  Future<void> downloadTranslation(String langCode) async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, completed: 0, error: null);

    final service = _ref.read(alQuranApiServiceProvider);
    try {
      final success = await service.downloadTranslation(
        lang: langCode,
        onProgress: (completed, total) {
          state = state.copyWith(completed: completed, total: total);
        },
      );

      if (!success) {
        state = state.copyWith(
          isDownloading: false,
          error: 'Some surahs failed to download. Tap to retry.',
        );
      } else {
        state = state.copyWith(isDownloading: false, error: null);
      }
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: e.toString());
    }

    // Refresh counts
    await _loadDownloadedCounts();
  }

  Future<void> deleteTranslation(String langCode) async {
    final service = _ref.read(alQuranApiServiceProvider);
    await service.deleteTranslation(langCode);
    await _loadDownloadedCounts();
  }

  Future<void> refreshCounts() async {
    await _loadDownloadedCounts();
  }
}

// ─────────────────────────────────────────────
// Surah Detail Provider (API-backed, language-aware)
// ─────────────────────────────────────────────

/// Parameters for fetching a surah with a specific language
class SurahFetchParams {
  final int surahId;
  final String lang;

  SurahFetchParams({required this.surahId, required this.lang});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurahFetchParams &&
          other.surahId == surahId &&
          other.lang == lang;

  @override
  int get hashCode => surahId.hashCode ^ lang.hashCode;
}

final apiSurahDetailProvider =
    FutureProvider.family<ApiSurahDetail?, SurahFetchParams>((ref, params) async {
  final service = ref.read(alQuranApiServiceProvider);
  return await service.getSurah(params.surahId, lang: params.lang);
});

// ─────────────────────────────────────────────
// Audio Reciters (extracted from first surah)
// ─────────────────────────────────────────────

/// We fetch surah 1 (Al-Fatiha) to get the list of available reciters,
/// since all surahs share the same reciter set.
final availableRecitersProvider = FutureProvider<List<ReciterInfo>>((ref) async {
  final service = ref.read(alQuranApiServiceProvider);
  final surah = await service.getSurah(1, lang: 'en');
  if (surah == null) return ReciterInfo.fallbackReciters;

  return surah.audio.entries.map((e) {
    return ReciterInfo(key: e.key, name: e.value.reciter);
  }).toList();
});

class ReciterInfo {
  final String key;
  final String name;

  ReciterInfo({required this.key, required this.name});

  static final fallbackReciters = [
    ReciterInfo(key: '1', name: 'Mishary Rashid Al-Afasy'),
    ReciterInfo(key: '2', name: 'Abu Bakr Al-Shatri'),
    ReciterInfo(key: '3', name: 'Nasser Al-Qatami'),
    ReciterInfo(key: '4', name: 'Yasser Al-Dosari'),
  ];
}
