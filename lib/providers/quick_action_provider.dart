import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:installed_apps/installed_apps.dart';

/// Provider for storing quick action app selections (phone, camera, etc.)
final quickActionProvider =
    StateNotifierProvider<QuickActionNotifier, QuickActions>((ref) {
      return QuickActionNotifier();
    });

class QuickActions {
  final String? phoneApp;
  final String? cameraApp;

  QuickActions({this.phoneApp, this.cameraApp});

  QuickActions copyWith({String? phoneApp, String? cameraApp}) {
    return QuickActions(
      phoneApp: phoneApp ?? this.phoneApp,
      cameraApp: cameraApp ?? this.cameraApp,
    );
  }
}

class QuickActionNotifier extends StateNotifier<QuickActions> {
  static const String _boxName = 'quickActions';
  Box? _box;

  // Common phone dialer package names (ordered by popularity)
  static const _commonDialers = [
    'com.google.android.dialer',
    'com.samsung.android.dialer',
    'com.android.dialer',
    'com.android.phone',
    'com.samsung.android.contacts',
    'com.oneplus.dialer',
    'com.miui.calls',
    'com.asus.contacts',
    'com.huawei.contacts',
  ];

  // Common camera package names (ordered by popularity)
  static const _commonCameras = [
    'com.google.android.GoogleCamera',
    'com.samsung.android.camera',
    'com.android.camera',
    'com.android.camera2',
    'com.oneplus.camera',
    'com.miui.camera',
    'com.huawei.camera',
    'com.asus.camera',
    'com.sec.android.app.camera',
    'com.motorola.camera3',
    'com.sonyericsson.android.camera',
    'org.codeaurora.snapcam',
  ];

  QuickActionNotifier() : super(QuickActions()) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    _loadFromHive();

    // Auto-detect if no apps are saved yet
    if (state.phoneApp == null || state.cameraApp == null) {
      await _autoDetectDefaults();
    }
  }

  void _loadFromHive() {
    final phoneApp = _box?.get('phoneApp') as String?;
    final cameraApp = _box?.get('cameraApp') as String?;
    state = QuickActions(phoneApp: phoneApp, cameraApp: cameraApp);
  }

  /// Auto-detect common phone and camera apps from installed apps
  Future<void> _autoDetectDefaults() async {
    try {
      final allApps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false,
        withIcon: false,
      );
      final installedPackages = allApps.map((a) => a.packageName).toSet();

      // Auto-detect phone app
      if (state.phoneApp == null) {
        for (final dialer in _commonDialers) {
          if (installedPackages.contains(dialer)) {
            debugPrint('QuickAction: Auto-detected phone app: $dialer');
            await setPhoneApp(dialer);
            break;
          }
        }
      }

      // Auto-detect camera app
      if (state.cameraApp == null) {
        for (final camera in _commonCameras) {
          if (installedPackages.contains(camera)) {
            debugPrint('QuickAction: Auto-detected camera app: $camera');
            await setCameraApp(camera);
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('QuickAction: Auto-detect error: $e');
    }
  }

  Future<void> setPhoneApp(String packageName) async {
    if (_box == null) return;
    await _box?.put('phoneApp', packageName);
    state = state.copyWith(phoneApp: packageName);
  }

  Future<void> setCameraApp(String packageName) async {
    if (_box == null) return;
    await _box?.put('cameraApp', packageName);
    state = state.copyWith(cameraApp: packageName);
  }

  void clearPhoneApp() {
    _box?.delete('phoneApp');
    state = state.copyWith(phoneApp: null);
  }

  void clearCameraApp() {
    _box?.delete('cameraApp');
    state = state.copyWith(cameraApp: null);
  }
}
