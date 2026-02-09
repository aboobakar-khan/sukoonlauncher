import 'package:flutter/services.dart';

/// Bridge to native Android AppBlockerService.
///
/// This service runs a foreground service that monitors the foreground app
/// every 500ms. If a blocked app is detected (even opened via notification
/// tap or recent apps), it immediately shows a blocking overlay.
///
/// Requires USAGE_STATS permission (user must grant in settings).
class NativeAppBlockerService {
  static const _channel = MethodChannel('com.minimalist.launcher/app_blocker');

  /// Start the native foreground blocker service
  static Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod('startService');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Stop the native foreground blocker service
  static Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod('stopService');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Sync the list of blocked packages to the native service.
  /// Call this whenever block rules change.
  /// If the list is empty, the service will auto-stop.
  /// If non-empty and service isn't running, it will auto-start.
  static Future<bool> updateBlockedPackages(List<String> packages) async {
    try {
      final result = await _channel.invokeMethod('updateBlockedPackages', {
        'packages': packages,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the native blocker service is currently running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if Usage Stats permission is granted (required for foreground detection)
  static Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod('hasUsageStatsPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Open system settings to grant Usage Stats permission
  static Future<bool> requestUsageStatsPermission() async {
    try {
      final result = await _channel.invokeMethod('requestUsageStatsPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if notification permission is granted (Android 13+ requires this)
  static Future<bool> hasNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod('hasNotificationPermission');
      return result == true;
    } catch (e) {
      return true; // Assume granted on older Android
    }
  }

  /// Request notification permission (Android 13+)
  static Future<bool> requestNotificationPermission() async {
    try {
      final result = await _channel.invokeMethod('requestNotificationPermission');
      return result == true;
    } catch (e) {
      return false;
    }
  }
}
