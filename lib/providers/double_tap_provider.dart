import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Actions that can be triggered by double-tapping on the home screen.
enum DoubleTapAction {
  lockScreen('Lock Screen', 'Turn off the display instantly'),
  flashlight('Flashlight', 'Toggle the camera flashlight'),
  openCamera('Open Camera', 'Quick launch the camera'),
  openApp('Open App', 'Launch a specific app'),
  expandNotifications('Notifications', 'Pull down the notification shade'),
  quickAccess('Quick Access', 'Samsung-style search & app grid'),
  none('Do Nothing', 'Disable double-tap action');

  final String label;
  final String description;
  const DoubleTapAction(this.label, this.description);
}

class DoubleTapState {
  final DoubleTapAction action;
  final String? appPackage; // only used when action == openApp

  const DoubleTapState({
    this.action = DoubleTapAction.lockScreen,
    this.appPackage,
  });

  DoubleTapState copyWith({DoubleTapAction? action, String? appPackage}) {
    return DoubleTapState(
      action: action ?? this.action,
      appPackage: appPackage ?? this.appPackage,
    );
  }
}

class DoubleTapNotifier extends StateNotifier<DoubleTapState> {
  DoubleTapNotifier() : super(const DoubleTapState()) {
    _init();
  }

  static const _boxName = 'settings';
  static const _keyAction = 'double_tap_action';
  static const _keyApp = 'double_tap_app';
  Box? _box;

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final actionStr = _box?.get(_keyAction, defaultValue: DoubleTapAction.lockScreen.name) as String?;
      final appPkg = _box?.get(_keyApp) as String?;
      state = DoubleTapState(
        action: DoubleTapAction.values.firstWhere(
          (a) => a.name == actionStr,
          orElse: () => DoubleTapAction.lockScreen,
        ),
        appPackage: appPkg,
      );
    } catch (_) {
      state = const DoubleTapState();
    }
  }

  Future<void> setAction(DoubleTapAction action, {String? appPackage}) async {
    state = DoubleTapState(action: action, appPackage: appPackage);
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_keyAction, action.name);
    if (appPackage != null) {
      await _box?.put(_keyApp, appPackage);
    }
  }
}

final doubleTapProvider =
    StateNotifierProvider<DoubleTapNotifier, DoubleTapState>(
        (ref) => DoubleTapNotifier());
