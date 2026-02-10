import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/deen_mode.dart';

/// Deen Mode State Notifier
class DeenModeNotifier extends StateNotifier<DeenModeSettings> {
  DeenModeNotifier() : super(DeenModeSettings()) {
    _loadSettings();
  }

  Box<DeenModeSettings>? _box;

  /// Load settings from Hive
  Future<void> _loadSettings() async {
    _box ??= await Hive.openBox<DeenModeSettings>('deen_mode');
    final settings = _box!.get('settings');
    if (settings != null) {
      // Check if session expired
      if (settings.isEnabled && settings.hasExpired) {
        // Session expired, disable and restore notifications
        state = settings.copyWith(isEnabled: false);
        await _restoreNotifications();
        await _saveSettings();
      } else {
        state = settings;
      }
    }
  }

  /// Save settings to Hive
  Future<void> _saveSettings() async {
    _box ??= await Hive.openBox<DeenModeSettings>('deen_mode');
    await _box!.put('settings', state);
  }

  /// Start Deen Mode
  Future<void> startDeenMode({
    required int durationMinutes,
    required String purpose,
  }) async {
    // Mute notifications
    await _muteNotifications();
    
    state = DeenModeSettings(
      isEnabled: true,
      startTime: DateTime.now(),
      durationMinutes: durationMinutes,
      purpose: purpose,
      notificationsMuted: true,
    );
    await _saveSettings();
  }

  /// End Deen Mode
  Future<void> endDeenMode() async {
    // Restore notifications
    await _restoreNotifications();
    
    state = state.copyWith(
      isEnabled: false,
      endTime: DateTime.now(),
    );
    await _saveSettings();
  }

  /// Set duration
  void setDuration(int minutes) {
    state = state.copyWith(durationMinutes: minutes);
  }

  /// Set purpose
  void setPurpose(String purpose) {
    state = state.copyWith(purpose: purpose);
  }

  /// Mute notifications (enable DND)
  Future<void> _muteNotifications() async {
    try {
      // Use platform channel to enable DND mode
      const platform = MethodChannel('com.sukoon.launcher/dnd');
      await platform.invokeMethod('enableDND');
    } catch (e) {
      // Silent fail - DND might not be available
    }
  }

  /// Restore notifications (disable DND)
  Future<void> _restoreNotifications() async {
    try {
      const platform = MethodChannel('com.sukoon.launcher/dnd');
      await platform.invokeMethod('disableDND');
    } catch (e) {
      // Silent fail
    }
  }

  /// Check if session is still valid
  bool get isSessionValid {
    if (!state.isEnabled) return false;
    return !state.hasExpired;
  }
}

/// Provider
final deenModeProvider = StateNotifierProvider<DeenModeNotifier, DeenModeSettings>(
  (ref) => DeenModeNotifier(),
);
