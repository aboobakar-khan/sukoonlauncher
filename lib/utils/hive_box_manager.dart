import 'package:hive_flutter/hive_flutter.dart';

/// Centralized Hive Box Manager
///
/// Prevents redundant box openings across the app.
/// Each box is opened once and cached in memory.
/// Access via `HiveBoxManager.get('boxName')` instead of `Hive.openBox()`.
///
/// This reduces I/O overhead significantly since many providers
/// and services independently call Hive.openBox on the same boxes.
class HiveBoxManager {
  static final Map<String, Box> _openBoxes = {};
  static final Map<String, LazyBox> _openLazyBoxes = {};

  /// Get or open a regular box (cached)
  static Future<Box<T>> get<T>(String name) async {
    if (_openBoxes.containsKey(name) && _openBoxes[name]!.isOpen) {
      return _openBoxes[name]! as Box<T>;
    }
    final box = await Hive.openBox<T>(name);
    _openBoxes[name] = box;
    return box;
  }

  /// Get or open a lazy box (for large datasets — only loads values on access)
  static Future<LazyBox<T>> getLazy<T>(String name) async {
    if (_openLazyBoxes.containsKey(name) && _openLazyBoxes[name]!.isOpen) {
      return _openLazyBoxes[name]! as LazyBox<T>;
    }
    final box = await Hive.openLazyBox<T>(name);
    _openLazyBoxes[name] = box;
    return box;
  }

  /// Check if a box is already open
  static bool isOpen(String name) {
    return _openBoxes.containsKey(name) && _openBoxes[name]!.isOpen;
  }

  /// Compact a box to reclaim disk space (call periodically)
  static Future<void> compact(String name) async {
    if (_openBoxes.containsKey(name) && _openBoxes[name]!.isOpen) {
      await _openBoxes[name]!.compact();
    }
  }

  /// Compact all open boxes (call on app pause/background)
  static Future<void> compactAll() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        try {
          await box.compact();
        } catch (_) {}
      }
    }
  }

  /// Close all boxes (call on app dispose)
  static Future<void> closeAll() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    for (final box in _openLazyBoxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _openBoxes.clear();
    _openLazyBoxes.clear();
  }
}
