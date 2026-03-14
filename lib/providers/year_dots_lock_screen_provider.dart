import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/hive_box_manager.dart';

/// Provider for year dots lock screen setting.
/// When enabled, the year dots lock screen shows when app resumes while device is locked.
final yearDotsLockScreenProvider =
    StateNotifierProvider<YearDotsLockScreenNotifier, bool>((ref) {
  return YearDotsLockScreenNotifier();
});

class YearDotsLockScreenNotifier extends StateNotifier<bool> {
  YearDotsLockScreenNotifier() : super(false) {
    _init();
  }

  static const _boxName = 'settings';
  static const _key = 'year_dots_lock_screen_enabled';

  Future<void> _init() async {
    final box = await HiveBoxManager.get(_boxName);
    state = box.get(_key, defaultValue: false) as bool? ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final box = await HiveBoxManager.get(_boxName);
    await box.put(_key, enabled);
  }
}
