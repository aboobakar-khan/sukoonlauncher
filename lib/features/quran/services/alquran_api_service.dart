import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../utils/hive_box_manager.dart';

/// Service for the Al-Quran API (alquran-api.pages.dev)
///
/// Provides:
/// - Multi-language surah/verse fetching
/// - Audio recitation URLs per surah
/// - Available languages listing
/// - Offline caching of translations and surah data
/// - Search functionality
class AlQuranApiService {
  static const String _baseUrl = 'https://alquran-api.pages.dev/api/quran';
  static const String _cacheBoxName = 'alquran_api_cache';
  static const String _translationBoxName = 'quran_translations';

  static Box<String>? _cacheBox;
  static Box<String>? _translationBox;
  static bool _isInitialized = false;

  /// Initialize cache boxes
  Future<void> init() async {
    if (_isInitialized && _cacheBox != null && _cacheBox!.isOpen) return;
    _cacheBox = await HiveBoxManager.get<String>(_cacheBoxName);
    _translationBox = await HiveBoxManager.get<String>(_translationBoxName);
    _isInitialized = true;
  }

  // ─────────────────────────────────────────────
  // LANGUAGES
  // ─────────────────────────────────────────────

  /// Fetch all available languages from the API
  Future<List<QuranLanguage>> getAvailableLanguages() async {
    await init();

    // Check cache first
    final cached = _cacheBox?.get('available_languages');
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .map((e) => QuranLanguage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/languages'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> langList;

        if (data is List) {
          langList = data;
        } else if (data is Map && data.containsKey('languages')) {
          langList = data['languages'] as List<dynamic>;
        } else {
          langList = [];
        }

        final languages = langList
            .map((e) => QuranLanguage.fromJson(e as Map<String, dynamic>))
            .toList();

        // Cache it
        await _cacheBox?.put('available_languages', jsonEncode(langList));
        return languages;
      }
    } catch (e) {
      debugPrint('AlQuranApiService: Failed to fetch languages: $e');
    }

    // Fallback hardcoded languages
    return QuranLanguage.fallbackLanguages;
  }

  // ─────────────────────────────────────────────
  // SURAH LIST
  // ─────────────────────────────────────────────

  /// Fetch all surahs (basic info) for a given language
  Future<List<ApiSurahInfo>> getAllSurahs({String lang = 'en'}) async {
    await init();

    final cacheKey = 'surahs_$lang';
    final cached = _cacheBox?.get(cacheKey);
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List<dynamic>;
        return list
            .map((e) => ApiSurahInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl?lang=$lang'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> surahList;

        if (data is List) {
          surahList = data;
        } else if (data is Map && data.containsKey('data')) {
          surahList = data['data'] as List<dynamic>;
        } else {
          surahList = [];
        }

        final surahs = surahList
            .map((e) => ApiSurahInfo.fromJson(e as Map<String, dynamic>))
            .toList();

        await _cacheBox?.put(cacheKey, jsonEncode(surahList));
        return surahs;
      }
    } catch (e) {
      debugPrint('AlQuranApiService: Failed to fetch surahs: $e');
    }

    return [];
  }

  // ─────────────────────────────────────────────
  // SURAH DETAIL (with verses, audio, translation)
  // ─────────────────────────────────────────────

  /// Fetch a specific surah with all verses, translations, and audio
  Future<ApiSurahDetail?> getSurah(int surahId, {String lang = 'en'}) async {
    await init();

    // Check offline cache first
    final cacheKey = 'surah_detail_${lang}_$surahId';
    final cached = _translationBox?.get(cacheKey);
    if (cached != null) {
      try {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        return ApiSurahDetail.fromJson(json);
      } catch (_) {}
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/surah/$surahId?lang=$lang'))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = ApiSurahDetail.fromJson(json);

        // Cache the full detail for offline
        await _translationBox?.put(cacheKey, response.body);
        return detail;
      }
    } catch (e) {
      debugPrint('AlQuranApiService: Failed to fetch surah $surahId: $e');
    }

    return null;
  }

  // ─────────────────────────────────────────────
  // DOWNLOAD TRANSLATION (offline)
  // ─────────────────────────────────────────────

  /// Download all 114 surahs for a specific language for offline reading.
  /// [onProgress] receives (completedSurahs, 114).
  Future<bool> downloadTranslation({
    required String lang,
    Function(int completed, int total)? onProgress,
  }) async {
    await init();
    int completed = 0;

    // Count already downloaded
    for (int i = 1; i <= 114; i++) {
      final key = 'surah_detail_${lang}_$i';
      if (_translationBox?.containsKey(key) == true) completed++;
    }
    onProgress?.call(completed, 114);

    // Short surahs first for quick progress feedback
    const priorityOrder = [
      112, 113, 114, 1, 108, 103, 110, 111, 109, 107, 105, 106, 104,
      102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 89, 88,
      87, 86, 85, 84, 83, 82, 81, 80, 79, 78,
      36, 67, 55, 56, 18, 32, 48, 71, 72, 73, 74, 75, 76, 77,
      2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
      19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 33, 34, 35,
      37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 49, 50, 51, 52, 53,
      54, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 68, 69, 70,
    ];

    for (final surahId in priorityOrder) {
      final key = 'surah_detail_${lang}_$surahId';
      if (_translationBox?.containsKey(key) == true) continue;

      try {
        final detail = await getSurah(surahId, lang: lang);
        if (detail != null) {
          completed++;
          onProgress?.call(completed, 114);
        }
      } catch (e) {
        debugPrint('AlQuranApiService: Download error surah $surahId: $e');
      }
      // Rate limit — be polite to the API
      await Future.delayed(const Duration(milliseconds: 250));
    }

    debugPrint('AlQuranApiService: Download complete for $lang: $completed/114');
    return completed >= 114;
  }

  /// Check how many surahs are downloaded for a language
  Future<int> getDownloadedCount(String lang) async {
    await init();
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      final key = 'surah_detail_${lang}_$i';
      if (_translationBox?.containsKey(key) == true) count++;
    }
    return count;
  }

  /// Check if full translation is downloaded
  Future<bool> isTranslationDownloaded(String lang) async {
    final count = await getDownloadedCount(lang);
    return count >= 114;
  }

  /// Delete cached translation for a language
  Future<void> deleteTranslation(String lang) async {
    await init();
    for (int i = 1; i <= 114; i++) {
      await _translationBox?.delete('surah_detail_${lang}_$i');
    }
  }

  // ─────────────────────────────────────────────
  // SEARCH
  // ─────────────────────────────────────────────

  /// Search the Quran for a query string
  Future<List<SearchResult>> search(String query, {String lang = 'en'}) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}&lang=$lang'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> results;

        if (data is List) {
          results = data;
        } else if (data is Map && data.containsKey('results')) {
          results = data['results'] as List<dynamic>;
        } else if (data is Map && data.containsKey('data')) {
          results = data['data'] as List<dynamic>;
        } else {
          results = [];
        }

        return results
            .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('AlQuranApiService: Search error: $e');
    }
    return [];
  }

  /// Clear all cached API data
  Future<void> clearCache() async {
    await init();
    await _cacheBox?.clear();
    await _translationBox?.clear();
  }
}

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────

/// Available language from the API
class QuranLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String direction; // "ltr" or "rtl"

  QuranLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.direction,
  });

  factory QuranLanguage.fromJson(Map<String, dynamic> json) {
    return QuranLanguage(
      code: json['code'] as String? ?? json['iso_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nativeName: json['nativeName'] as String? ?? json['native_name'] as String? ?? '',
      direction: json['direction'] as String? ?? 'ltr',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'nativeName': nativeName,
        'direction': direction,
      };

  bool get isRtl => direction == 'rtl';

  /// Fallback languages when API is unavailable
  static final fallbackLanguages = [
    QuranLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', direction: 'rtl'),
    QuranLanguage(code: 'en', name: 'English', nativeName: 'English', direction: 'ltr'),
    QuranLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', direction: 'rtl'),
    QuranLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', direction: 'ltr'),
    QuranLanguage(code: 'fr', name: 'French', nativeName: 'Français', direction: 'ltr'),
    QuranLanguage(code: 'es', name: 'Spanish', nativeName: 'Español', direction: 'ltr'),
    QuranLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', direction: 'ltr'),
    QuranLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', direction: 'ltr'),
    QuranLanguage(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', direction: 'ltr'),
    QuranLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', direction: 'ltr'),
    QuranLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский', direction: 'ltr'),
    QuranLanguage(code: 'de', name: 'German', nativeName: 'Deutsch', direction: 'ltr'),
    QuranLanguage(code: 'zh', name: 'Chinese', nativeName: '中文', direction: 'ltr'),
  ];
}

/// Basic surah info from the list endpoint
class ApiSurahInfo {
  final int id;
  final String name;
  final String transliteration;
  final String translation;
  final String type;
  final int totalVerses;

  ApiSurahInfo({
    required this.id,
    required this.name,
    required this.transliteration,
    required this.translation,
    required this.type,
    required this.totalVerses,
  });

  factory ApiSurahInfo.fromJson(Map<String, dynamic> json) {
    return ApiSurahInfo(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      type: json['type'] as String? ?? '',
      totalVerses: json['total_verses'] as int? ?? 0,
    );
  }
}

/// Audio recitation info
class AudioRecitation {
  final String reciter;
  final String url;
  final String type;

  AudioRecitation({
    required this.reciter,
    required this.url,
    required this.type,
  });

  factory AudioRecitation.fromJson(Map<String, dynamic> json) {
    return AudioRecitation(
      reciter: json['reciter'] as String? ?? '',
      url: json['url'] as String? ?? json['originalUrl'] as String? ?? '',
      type: json['type'] as String? ?? 'complete_surah',
    );
  }

  Map<String, dynamic> toJson() => {
        'reciter': reciter,
        'url': url,
        'type': type,
      };
}

/// Verse from the API
class ApiVerse {
  final int id;
  final String text;       // Arabic text
  final String? translation;

  ApiVerse({
    required this.id,
    required this.text,
    this.translation,
  });

  factory ApiVerse.fromJson(Map<String, dynamic> json) {
    return ApiVerse(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'translation': translation,
      };
}

/// Full surah detail from the API
class ApiSurahDetail {
  final String language;
  final int id;
  final String name;
  final String transliteration;
  final String translation;
  final String type;
  final int totalVerses;
  final Map<String, AudioRecitation> audio; // key = reciter index
  final List<ApiVerse> verses;

  ApiSurahDetail({
    required this.language,
    required this.id,
    required this.name,
    required this.transliteration,
    required this.translation,
    required this.type,
    required this.totalVerses,
    required this.audio,
    required this.verses,
  });

  factory ApiSurahDetail.fromJson(Map<String, dynamic> json) {
    // Parse audio map
    final audioMap = <String, AudioRecitation>{};
    final audioJson = json['audio'];
    if (audioJson is Map<String, dynamic>) {
      audioJson.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          audioMap[key] = AudioRecitation.fromJson(value);
        }
      });
    }

    // Parse verses list
    final versesJson = json['verses'] as List<dynamic>? ?? [];
    final verses = versesJson
        .map((v) => ApiVerse.fromJson(v as Map<String, dynamic>))
        .toList();

    return ApiSurahDetail(
      language: json['language'] as String? ?? 'en',
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      type: json['type'] as String? ?? '',
      totalVerses: json['total_verses'] as int? ?? verses.length,
      audio: audioMap,
      verses: verses,
    );
  }

  /// Get list of available reciters
  List<AudioRecitation> get reciters => audio.values.toList();

  /// Get audio URL for a specific reciter (by key "1", "2", etc.)
  String? getAudioUrl(String reciterKey) => audio[reciterKey]?.url;
}

/// Search result from the API
class SearchResult {
  final int surahId;
  final String surahName;
  final String surahTransliteration;
  final int verseId;
  final String text;
  final String? translation;

  SearchResult({
    required this.surahId,
    required this.surahName,
    required this.surahTransliteration,
    required this.verseId,
    required this.text,
    this.translation,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      surahId: json['surah_id'] as int? ?? json['surah'] as int? ?? 0,
      surahName: json['surah_name'] as String? ?? json['name'] as String? ?? '',
      surahTransliteration: json['surah_transliteration'] as String? ??
          json['transliteration'] as String? ?? '',
      verseId: json['verse_id'] as int? ?? json['verse'] as int? ?? json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String?,
    );
  }
}
