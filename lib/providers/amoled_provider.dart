import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// AMOLED Display Mode Provider
/// When enabled, forces pure #000000 backgrounds everywhere
/// for maximum battery saving on OLED/AMOLED screens.
/// Enabled by default.

final amoledProvider = StateNotifierProvider<AmoledNotifier, bool>(
  (ref) => AmoledNotifier(),
);

class AmoledNotifier extends StateNotifier<bool> {
  AmoledNotifier() : super(true) {
    _load();
  }

  static const _boxName = 'settingsBox';
  static const _key = 'amoledMode';

  Future<void> _load() async {
    final box = await Hive.openBox(_boxName);
    // Default to true (enabled)
    state = box.get(_key, defaultValue: true) as bool;
  }

  Future<void> toggle() async {
    state = !state;
    final box = await Hive.openBox(_boxName);
    await box.put(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final box = await Hive.openBox(_boxName);
    await box.put(_key, value);
  }
}
