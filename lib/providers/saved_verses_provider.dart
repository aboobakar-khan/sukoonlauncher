import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Saved Verses — bookmark verses from Verse of the Moment
// ─────────────────────────────────────────────────────────────────────────────

class SavedVerse {
  final String arabic;
  final String translation;
  final String surahName;
  final int surahId;
  final int verseNumber;
  final DateTime savedAt;

  const SavedVerse({
    required this.arabic,
    required this.translation,
    required this.surahName,
    required this.surahId,
    required this.verseNumber,
    required this.savedAt,
  });

  /// Unique key so we don't save duplicates
  String get key => '$surahId:$verseNumber';

  Map<String, dynamic> toJson() => {
    'arabic': arabic,
    'translation': translation,
    'surahName': surahName,
    'surahId': surahId,
    'verseNumber': verseNumber,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedVerse.fromJson(Map<String, dynamic> json) => SavedVerse(
    arabic: json['arabic'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
    surahName: json['surahName'] as String? ?? '',
    surahId: json['surahId'] as int? ?? 0,
    verseNumber: json['verseNumber'] as int? ?? 0,
    savedAt: json['savedAt'] != null
        ? DateTime.parse(json['savedAt'] as String)
        : DateTime.now(),
  );
}

class SavedVersesNotifier extends StateNotifier<List<SavedVerse>> {
  SavedVersesNotifier() : super([]) {
    _init();
  }

  static const _prefsKey = 'saved_verses';

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        final list = (jsonDecode(json) as List)
            .map((e) => SavedVerse.fromJson(e as Map<String, dynamic>))
            .toList();
        // Sort newest first
        list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
        state = list;
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(state.map((v) => v.toJson()).toList()),
    );
  }

  /// Save a verse (from verse card data map)
  void saveVerse(Map<String, dynamic> verseData) {
    final verse = SavedVerse(
      arabic: verseData['arabic'] as String? ?? '',
      translation: verseData['translation'] as String? ?? '',
      surahName: verseData['surahTransliteration'] as String? ?? '',
      surahId: verseData['surahId'] as int? ?? 0,
      verseNumber: verseData['verseNumber'] as int? ?? 0,
      savedAt: DateTime.now(),
    );

    // Check for duplicates
    if (state.any((v) => v.key == verse.key)) return;

    state = [verse, ...state];
    _save();
  }

  /// Remove a saved verse by key
  void removeVerse(String key) {
    state = state.where((v) => v.key != key).toList();
    _save();
  }

  /// Check if a verse is already saved
  bool isVerseSaved(int surahId, int verseNumber) {
    return state.any((v) => v.surahId == surahId && v.verseNumber == verseNumber);
  }
}

final savedVersesProvider =
    StateNotifierProvider<SavedVersesNotifier, List<SavedVerse>>((ref) {
  return SavedVersesNotifier();
});

/// Quick check if a specific verse is saved
final isVerseSavedProvider = Provider.family<bool, String>((ref, key) {
  final verses = ref.watch(savedVersesProvider);
  return verses.any((v) => v.key == key);
});
