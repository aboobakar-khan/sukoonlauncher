import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../utils/hive_box_manager.dart';

/// AMOLED Display Mode Provider
/// When enabled, forces pure #000000 backgrounds everywhere
/// for maximum battery saving on OLED/AMOLED screens.
/// Enabled by default for the black + white minimalist look.

final amoledProvider = StateNotifierProvider<AmoledNotifier, bool>(
  (ref) => AmoledNotifier(),
);

class AmoledNotifier extends StateNotifier<bool> {
  AmoledNotifier() : super(false) {    _load();
  }

  static const _boxName = 'settingsBox';
  static const _key = 'amoledMode';
  Box? _box;

  Future<void> _load() async {
    _box = await HiveBoxManager.get(_boxName);
    // Default to false — standard dark background, not pure black
    state = _box!.get(_key, defaultValue: false) as bool;
  }

  Future<void> toggle() async {
    state = !state;
    _box ??= await HiveBoxManager.get(_boxName);
    _box!.put(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    _box ??= await HiveBoxManager.get(_boxName);
    _box!.put(_key, value);
  }
}
