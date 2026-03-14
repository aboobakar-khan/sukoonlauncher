import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/tafseer.dart';
import '../../../utils/hive_box_manager.dart';

/// Service for fetching and caching Tafseer (Quran commentary)
/// 
/// Cache Strategy:
/// - Downloads store whole surah tafseer as individual verse entries
/// - Retrieval checks cache first, then falls back to API
/// - Works fully offline once downloaded
class TafseerService {
  static const String _baseUrl = 'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir';
  static const String _defaultEdition = 'en-tafisr-ibn-kathir';
  static const String _cacheBoxName = 'tafseer_cache';
  
  static Box<String>? _cacheBox;
  static bool _isInitialized = false;

  /// Initialize the cache box (singleton pattern for shared access)
  Future<void> init() async {
    if (_isInitialized && _cacheBox != null && _cacheBox!.isOpen) {
      return;
    }
    _cacheBox = await HiveBoxManager.get<String>(_cacheBoxName);
    _isInitialized = true;
    debugPrint('TafseerService: Initialized, cache has ${_cacheBox?.length ?? 0} entries');
  }

  /// Get tafseer for a specific ayah - CACHE FIRST approach
  Future<Tafseer?> getTafseer(int surahId, int ayahId, {String? edition}) async {
    await init();
    final requestedEdition = edition ?? _defaultEdition;
    final cacheKey = '$requestedEdition-$surahId-$ayahId';

    // 1. ALWAYS check cache first (most important for offline!)
    try {
      final cached = _cacheBox?.get(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        debugPrint('TafseerService: ✓ Cache HIT for $surahId:$ayahId');
        final json = jsonDecode(cached) as Map<String, dynamic>;
        final text = json['text'] as String? ?? '';
        if (text.isNotEmpty) {
          return Tafseer(
            surahId: surahId,
            ayahId: ayahId,
            text: text,
            edition: requestedEdition,
          );
        }
      }
    } catch (e) {
      debugPrint('TafseerService: Cache read error: $e');
    }

    // 2. If requested edition not in cache, try default edition cache (for offline)
    if (requestedEdition != _defaultEdition) {
      final defaultCacheKey = '$_defaultEdition-$surahId-$ayahId';
      try {
        final defaultCached = _cacheBox?.get(defaultCacheKey);
        if (defaultCached != null && defaultCached.isNotEmpty) {
          debugPrint('TafseerService: ✓ Fallback cache HIT for $surahId:$ayahId');
          final json = jsonDecode(defaultCached) as Map<String, dynamic>;
          final text = json['text'] as String? ?? '';
          if (text.isNotEmpty) {
            return Tafseer(
              surahId: surahId,
              ayahId: ayahId,
              text: text,
              edition: _defaultEdition,
            );
          }
        }
      } catch (e) {
        debugPrint('TafseerService: Fallback cache error: $e');
      }
    }

    debugPrint('TafseerService: Cache MISS for $surahId:$ayahId, trying API...');

    // 3. Try to fetch from API (only if not in cache)
    return await _fetchAndCacheTafseer(surahId, ayahId, requestedEdition);
  }

  /// Fetch tafseer from API and cache it
  Future<Tafseer?> _fetchAndCacheTafseer(int surahId, int ayahId, String edition) async {
    try {
      final url = '$_baseUrl/$edition/$surahId/$ayahId.json';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final text = json['text'] as String? ?? '';
        
        if (text.isEmpty) {
          debugPrint('TafseerService: API returned empty text for $surahId:$ayahId');
          return null;
        }

        // Cache it
        final cacheKey = '$edition-$surahId-$ayahId';
        await _cacheBox?.put(cacheKey, jsonEncode({'text': text}));
        debugPrint('TafseerService: ✓ Fetched and cached $surahId:$ayahId');

        return Tafseer(
          surahId: surahId,
          ayahId: ayahId,
          text: text,
          edition: edition,
        );
      } else {
        debugPrint('TafseerService: API returned ${response.statusCode} for $surahId:$ayahId');
      }
    } catch (e) {
      debugPrint('TafseerService: Fetch error for $surahId:$ayahId - $e');
    }
    return null;
  }

  /// Download entire surah tafseer for offline reading
  Future<bool> downloadSurahTafseer(int surahId, int totalVerses, {String? edition, Function(int, int)? onProgress}) async {
    await init();
    final ed = edition ?? _defaultEdition;

    try {
      final url = '$_baseUrl/$ed/$surahId.json';
      debugPrint('TafseerService: Downloading surah $surahId from $url');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Handle different API response structures
        List<dynamic> tafsirs = [];
        if (json.containsKey('tafsirs')) {
          tafsirs = json['tafsirs'] as List<dynamic>? ?? [];
        } else if (json.containsKey('ayahs')) {
          tafsirs = json['ayahs'] as List<dynamic>? ?? [];
        }

        if (tafsirs.isEmpty) {
          debugPrint('TafseerService: No tafsirs found in response for surah $surahId');
          debugPrint('TafseerService: Response keys: ${json.keys.toList()}');
          return false;
        }

        int savedCount = 0;
        for (int i = 0; i < tafsirs.length; i++) {
          final item = tafsirs[i] as Map<String, dynamic>;
          
          // Try different field names for verse number
          int? ayahId = item['verse_number'] as int?;
          ayahId ??= item['ayah'] as int?;
          ayahId ??= item['verse'] as int?;
          ayahId ??= item['aya'] as int?;
          ayahId ??= (i + 1); // Default to index + 1
          
          // Try different field names for text
          String? text = item['text'] as String?;
          text ??= item['tafsir'] as String?;
          text ??= item['content'] as String?;
          text ??= '';

          if (text.isNotEmpty) {
            final cacheKey = '$ed-$surahId-$ayahId';
            await _cacheBox?.put(cacheKey, jsonEncode({'text': text}));
            savedCount++;
          }

          onProgress?.call(i + 1, tafsirs.length);
        }

        // Mark surah as downloaded
        await _cacheBox?.put('downloaded-$ed-$surahId', 'true');
        debugPrint('TafseerService: Saved $savedCount verses for surah $surahId');
        return savedCount > 0;
      } else {
        debugPrint('TafseerService: Download failed with status ${response.statusCode} for surah $surahId');
      }
    } catch (e) {
      debugPrint('Surah tafseer download error: $e');
    }
    return false;
  }

  /// Check if surah tafseer is downloaded
  Future<bool> isSurahDownloaded(int surahId, {String? edition}) async {
    await init();
    final ed = edition ?? _defaultEdition;
    return _cacheBox?.get('downloaded-$ed-$surahId') == 'true';
  }

  /// Surah verse counts for full tafseer download
  static const Map<int, int> surahVerses = {
    1: 7, 2: 286, 3: 200, 4: 176, 5: 120, 6: 165, 7: 206, 8: 75,
    9: 129, 10: 109, 11: 123, 12: 111, 13: 43, 14: 52, 15: 99, 16: 128,
    17: 111, 18: 110, 19: 98, 20: 135, 21: 112, 22: 78, 23: 118, 24: 64,
    25: 77, 26: 227, 27: 93, 28: 88, 29: 69, 30: 60, 31: 34, 32: 30,
    33: 73, 34: 54, 35: 45, 36: 83, 37: 182, 38: 88, 39: 75, 40: 85,
    41: 54, 42: 53, 43: 89, 44: 59, 45: 37, 46: 35, 47: 38, 48: 29,
    49: 18, 50: 45, 51: 60, 52: 49, 53: 62, 54: 55, 55: 78, 56: 96,
    57: 29, 58: 22, 59: 24, 60: 13, 61: 14, 62: 11, 63: 11, 64: 18,
    65: 12, 66: 12, 67: 30, 68: 52, 69: 52, 70: 44, 71: 28, 72: 28,
    73: 20, 74: 56, 75: 40, 76: 31, 77: 50, 78: 40, 79: 46, 80: 42,
    81: 29, 82: 19, 83: 36, 84: 25, 85: 22, 86: 17, 87: 19, 88: 26,
    89: 30, 90: 20, 91: 15, 92: 21, 93: 11, 94: 8, 95: 8, 96: 19,
    97: 5, 98: 8, 99: 8, 100: 11, 101: 11, 102: 8, 103: 3, 104: 9,
    105: 5, 106: 4, 107: 7, 108: 3, 109: 6, 110: 3, 111: 5, 112: 4,
    113: 5, 114: 6,
  };

  /// Check how many surahs are downloaded for an edition
  Future<int> getDownloadedSurahCount({String? edition}) async {
    await init();
    final ed = edition ?? _defaultEdition;
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (_cacheBox?.get('downloaded-$ed-$i') == 'true') count++;
    }
    return count;
  }

  /// Check if full tafseer (all 114 surahs) is downloaded for an edition
  Future<bool> isFullTafseerDownloaded({String? edition}) async {
    final count = await getDownloadedSurahCount(edition: edition);
    return count >= 114;
  }

  /// Download COMPLETE tafseer (all 114 surahs) for a specific edition.
  /// Returns true if all surahs downloaded successfully.
  /// [onProgress] callback: (completedSurahs, totalSurahs)
  Future<bool> downloadFullTafseer({
    required String edition,
    Function(int completed, int total)? onProgress,
  }) async {
    await init();
    debugPrint('TafseerService: Starting full tafseer download for $edition');

    // Priority: Short surahs first (Juz Amma), then commonly read, then rest
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

    int completed = 0;
    // Count already downloaded
    for (final surahId in priorityOrder) {
      if (_cacheBox?.get('downloaded-$edition-$surahId') == 'true') completed++;
    }
    onProgress?.call(completed, 114);

    for (final surahId in priorityOrder) {
      if (_cacheBox?.get('downloaded-$edition-$surahId') == 'true') continue;

      final verses = surahVerses[surahId] ?? 7;
      try {
        final success = await downloadSurahTafseer(surahId, verses, edition: edition);
        if (success) {
          completed++;
          onProgress?.call(completed, 114);
          debugPrint('TafseerService: Full download – Surah $surahId done ($completed/114)');
        }
      } catch (e) {
        debugPrint('TafseerService: Full download – Error on surah $surahId: $e');
      }
      // Small delay to not overwhelm API
      await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint('TafseerService: Full tafseer download complete: $completed/114');
    return completed >= 114;
  }

  /// Debug: Get cache stats
  Future<Map<String, dynamic>> getCacheStats() async {
    await init();
    final keys = _cacheBox?.keys.toList() ?? [];
    final downloadedSurahs = keys.where((k) => k.toString().startsWith('downloaded-')).length;
    final verseEntries = keys.length - downloadedSurahs;
    return {
      'totalEntries': keys.length,
      'downloadedSurahs': downloadedSurahs,
      'verseEntries': verseEntries,
    };
  }

  /// Clear all cached tafseer
  Future<void> clearCache() async {
    await init();
    await _cacheBox?.clear();
    debugPrint('TafseerService: Cache cleared');
  }
}
