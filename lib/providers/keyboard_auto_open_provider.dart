import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Controls whether the keyboard auto-opens when the app list screen appears.
class KeyboardAutoOpenNotifier extends StateNotifier<bool> {
  /// Start with `false` to avoid auto-opening keyboard before Hive loads.
  /// This prevents a race where the user disabled the toggle but _init()
  /// hasn't completed yet — without this, the old default `true` would
  /// erroneously open the keyboard.
  KeyboardAutoOpenNotifier() : super(false) {
    _init();
  }

  static const _boxName = 'settings';
  static const _key = 'keyboard_auto_open';
  Box? _box;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final saved = _box?.get(_key);
      // Default to false — keyboard should NOT auto-open (less intrusive)
      state = saved is bool ? saved : false;
    } catch (_) {
      state = false;
    }
    _initialized = true;
  }

  Future<void> toggle() async {
    state = !state;
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_key, state);
  }
}

final keyboardAutoOpenProvider =
    StateNotifierProvider<KeyboardAutoOpenNotifier, bool>(
        (ref) => KeyboardAutoOpenNotifier());
