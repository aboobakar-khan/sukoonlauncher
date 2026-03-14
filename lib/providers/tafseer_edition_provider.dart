import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../utils/hive_box_manager.dart';

/// Tafseer Edition model
class TafseerEdition {
  final int id;
  final String name;
  final String authorName;
  final String slug;
  final String language;

  TafseerEdition({
    required this.id,
    required this.name,
    required this.authorName,
    required this.slug,
    required this.language,
  });

  factory TafseerEdition.fromJson(Map<String, dynamic> json) {
    return TafseerEdition(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      language: json['language_name'] as String? ?? '',
    );
  }

  static TafseerEdition get defaultEdition => TafseerEdition(
    id: 169,
    name: 'Tafsir Ibn Kathir (abridged)',
    authorName: 'Hafiz Ibn Kathir',
    slug: 'en-tafisr-ibn-kathir',
    language: 'english',
  );
}

/// Provider for available tafseer editions
final tafseerEditionsProvider = FutureProvider<List<TafseerEdition>>((ref) async {
  try {
    final response = await http.get(
      Uri.parse('https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/editions.json'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(response.body);
      return json.map((e) => TafseerEdition.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (e) {
    // Return default list on error
  }
  
  // Fallback to common editions
  return [
    TafseerEdition.defaultEdition,
    TafseerEdition(
      id: 168,
      name: 'Maarif-ul-Quran',
      authorName: 'Mufti Muhammad Shafi',
      slug: 'en-tafsir-maarif-ul-quran',
      language: 'english',
    ),
    TafseerEdition(
      id: 160,
      name: 'Tafsir Ibn Kathir (Urdu)',
      authorName: 'Hafiz Ibn Kathir',
      slug: 'ur-tafseer-ibn-e-kaseer',
      language: 'urdu',
    ),
  ];
});

/// Provider for selected tafseer edition
final selectedTafseerEditionProvider = StateNotifierProvider<SelectedTafseerNotifier, TafseerEdition>((ref) {
  return SelectedTafseerNotifier();
});

class SelectedTafseerNotifier extends StateNotifier<TafseerEdition> {
  static const String _boxName = 'tafseer_settings';
  static const String _key = 'selected_edition';
  Box<String>? _box;

  SelectedTafseerNotifier() : super(TafseerEdition.defaultEdition) {
    _init();
  }

  Future<void> _init() async {
    _box = await HiveBoxManager.get<String>(_boxName);
    final saved = _box?.get(_key);
    if (saved != null) {
      try {
        final json = jsonDecode(saved) as Map<String, dynamic>;
        state = TafseerEdition(
          id: json['id'] as int? ?? 169,
          name: json['name'] as String? ?? '',
          authorName: json['authorName'] as String? ?? '',
          slug: json['slug'] as String? ?? 'en-tafisr-ibn-kathir',
          language: json['language'] as String? ?? 'english',
        );
      } catch (e) {
        // Use default
      }
    }
  }

  Future<void> setEdition(TafseerEdition edition) async {
    state = edition;
    _box ??= await HiveBoxManager.get<String>(_boxName);
    await _box?.put(_key, jsonEncode({
      'id': edition.id,
      'name': edition.name,
      'authorName': edition.authorName,
      'slug': edition.slug,
      'language': edition.language,
    }));
  }
}
