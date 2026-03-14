import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Provider for Productivity Hub light/dark mode toggle
/// Persisted via Hive so user preference is remembered
final hubThemeLightModeProvider =
    StateNotifierProvider<HubThemeNotifier, bool>((ref) {
  return HubThemeNotifier();
});

class HubThemeNotifier extends StateNotifier<bool> {
  static const _boxName = 'settings';
  static const _key = 'hub_light_mode';

  HubThemeNotifier() : super(false) {
    _load();
  }

  void _load() {
    try {
      final box = Hive.box(_boxName);
      state = box.get(_key, defaultValue: false) as bool;
    } catch (_) {
      state = false;
    }
  }

  void toggle() {
    state = !state;
    _save();
  }

  void set(bool value) {
    state = value;
    _save();
  }

  void _save() {
    try {
      Hive.box(_boxName).put(_key, state);
    } catch (_) {}
  }
}
