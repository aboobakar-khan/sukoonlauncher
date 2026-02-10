import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../services/native_app_blocker_service.dart';
import '../utils/hive_box_manager.dart';

/// ─────────────────────────────────────────────
/// Zen Mode State
/// ─────────────────────────────────────────────

class ZenModeState {
  final bool isActive;
  final DateTime? startTime;
  final int durationMinutes;
  final List<String> emergencyContacts; // phone numbers
  final int sessionsCompleted;

  ZenModeState({
    this.isActive = false,
    this.startTime,
    this.durationMinutes = 30,
    this.emergencyContacts = const [],
    this.sessionsCompleted = 0,
  });

  ZenModeState copyWith({
    bool? isActive,
    DateTime? startTime,
    int? durationMinutes,
    List<String>? emergencyContacts,
    int? sessionsCompleted,
  }) {
    return ZenModeState(
      isActive: isActive ?? this.isActive,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
    );
  }

  Duration get remainingTime {
    if (!isActive || startTime == null) return Duration.zero;
    final end = startTime!.add(Duration(minutes: durationMinutes));
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasExpired {
    if (!isActive || startTime == null) return false;
    return remainingTime <= Duration.zero;
  }

  double get progress {
    if (!isActive || startTime == null) return 0.0;
    final elapsed = DateTime.now().difference(startTime!);
    final total = Duration(minutes: durationMinutes);
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  String get remainingFormatted {
    final r = remainingTime;
    final m = r.inMinutes;
    final s = r.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// ─────────────────────────────────────────────
/// Zen Mode Provider
/// ─────────────────────────────────────────────

class ZenModeNotifier extends StateNotifier<ZenModeState> {
  ZenModeNotifier() : super(ZenModeState()) {
    _init();
  }

  static const _boxName = 'zen_mode_box';
  static const _dndChannel = MethodChannel('com.minimalist.launcher/dnd');
  static const _appChannel = MethodChannel('com.minimalist.launcher/apps');
  static const _blockerChannel = MethodChannel('com.minimalist.launcher/app_blocker');

  Box? _box;

  Future<void> _init() async {
    _box = await HiveBoxManager.get(_boxName);

    final isActive = _box!.get('isActive', defaultValue: false) as bool;
    final startMillis = _box!.get('startTime') as int?;
    final duration = _box!.get('durationMinutes', defaultValue: 30) as int;
    final contacts = (_box!.get('emergencyContacts', defaultValue: <String>[]) as List)
        .cast<String>();
    final sessions = _box!.get('sessionsCompleted', defaultValue: 0) as int;

    final startTime = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis)
        : null;

    state = ZenModeState(
      isActive: isActive,
      startTime: startTime,
      durationMinutes: duration,
      emergencyContacts: contacts,
      sessionsCompleted: sessions,
    );

    // If was active but timer expired (e.g. app was killed), end it
    if (isActive && state.hasExpired) {
      await endZenMode();
    }
  }

  /// Start Zen Mode — blocks ALL apps, enables DND
  Future<void> startZenMode(int durationMinutes) async {
    // 1. Get all installed app packages
    List<String> allPackages = [];
    try {
      final result = await _appChannel.invokeMethod('getInstalledApps');
      if (result is List) {
        allPackages = result
            .map((app) => (app as Map)['package'] as String)
            .where((pkg) =>
                pkg != 'com.example.minimalist_app' && // our app
                !pkg.startsWith('com.android.server') &&
                pkg != 'com.android.phone' && // phone app
                pkg != 'com.android.dialer' && // dialer
                pkg != 'com.google.android.dialer' &&
                pkg != 'com.android.incallui' &&
                pkg != 'com.android.camera' &&
                pkg != 'com.android.camera2')
            .toList();
      }
    } catch (e) {
      // If can't get packages, use a broad block approach
    }

    // 2. Send to native blocker
    if (allPackages.isNotEmpty) {
      await NativeAppBlockerService.updateBlockedPackages(allPackages);
    }

    // 3. Enable Zen Mode in native service (aggressive lockdown)
    try {
      await _blockerChannel.invokeMethod('setZenMode', {'active': true});
    } catch (_) {}

    // 4. Enable DND
    try {
      await _dndChannel.invokeMethod('enableDND');
    } catch (_) {}

    // 5. Update state
    state = state.copyWith(
      isActive: true,
      startTime: DateTime.now(),
      durationMinutes: durationMinutes,
    );

    // 6. Persist
    await _box?.put('isActive', true);
    await _box?.put('startTime', DateTime.now().millisecondsSinceEpoch);
    await _box?.put('durationMinutes', durationMinutes);
  }

  /// End Zen Mode — unblocks all apps, disables DND
  Future<void> endZenMode() async {
    // 1. Disable Zen Mode in native service
    try {
      await _blockerChannel.invokeMethod('setZenMode', {'active': false});
    } catch (_) {}

    // 2. Stop native blocker
    await NativeAppBlockerService.updateBlockedPackages([]);
    await NativeAppBlockerService.stopService();

    // 3. Disable DND
    try {
      await _dndChannel.invokeMethod('disableDND');
    } catch (_) {}

    // 4. Increment sessions
    final newSessions = state.sessionsCompleted + 1;

    // 5. Update state
    state = state.copyWith(
      isActive: false,
      sessionsCompleted: newSessions,
    );

    // 6. Persist
    await _box?.put('isActive', false);
    await _box?.put('sessionsCompleted', newSessions);
  }

  /// Set duration for next session
  void setDuration(int minutes) {
    state = state.copyWith(durationMinutes: minutes);
    _box?.put('durationMinutes', minutes);
  }

  /// Manage emergency contacts
  void addEmergencyContact(String number) {
    final updated = [...state.emergencyContacts, number];
    state = state.copyWith(emergencyContacts: updated);
    _box?.put('emergencyContacts', updated);
  }

  void removeEmergencyContact(int index) {
    final updated = [...state.emergencyContacts]..removeAt(index);
    state = state.copyWith(emergencyContacts: updated);
    _box?.put('emergencyContacts', updated);
  }

  /// Check & auto-end if expired
  bool checkAndAutoEnd() {
    if (state.isActive && state.hasExpired) {
      endZenMode();
      return true;
    }
    return false;
  }
}

/// Provider
final zenModeProvider = StateNotifierProvider<ZenModeNotifier, ZenModeState>(
  (ref) => ZenModeNotifier(),
);
