import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/hive_box_manager.dart';

/// Recent Apps Provider - Tracks recently launched apps
/// Stores package names in order of most recent first
class RecentAppsNotifier extends StateNotifier<List<String>> {
  static const String _boxName = 'recentAppsBox';
  static const String _key = 'recentApps';
  static const int _maxRecent = 10;

  RecentAppsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = await HiveBoxManager.get(_boxName);
      final saved = box.get(_key);
      if (saved != null) {
        state = List<String>.from(saved);
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _save() async {
    try {
      final box = await HiveBoxManager.get(_boxName);
      await box.put(_key, state);
    } catch (e) {
      // Silent fail
    }
  }

  /// Add app to recent list (moves to front if already exists)
  void addRecent(String packageName) {
    // Remove if exists
    final newList = state.where((p) => p != packageName).toList();
    // Add to front
    newList.insert(0, packageName);
    // Keep only max recent
    if (newList.length > _maxRecent) {
      newList.removeRange(_maxRecent, newList.length);
    }
    state = newList;
    _save();
  }

  /// Get recent app package names
  List<String> get recentPackages => state;
}

final recentAppsProvider = StateNotifierProvider<RecentAppsNotifier, List<String>>(
  (ref) => RecentAppsNotifier(),
);
