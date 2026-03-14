import 'package:flutter/services.dart';

/// Service to open Android app settings for uninstall functionality
class AppSettingsService {
  static const MethodChannel _channel = MethodChannel('app_settings');

  /// Directly open uninstall dialog for a specific package
  /// This shows the system uninstall confirmation dialog
  /// Returns true if the intent was launched successfully
  static Future<bool> uninstallApp(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('uninstallApp', {
        'packageName': packageName,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Open the Android app settings page for a specific package
  /// This allows the user to view app details and uninstall from there
  static Future<bool> openAppSettings(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('openAppSettings', {
        'packageName': packageName,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Expand the system notification / status-bar panel
  static Future<bool> expandNotifications() async {
    try {
      final result = await _channel.invokeMethod<bool>('expandNotifications');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Launch Google Pay using native Android intents
  /// Tries multiple package names and falls back to web version
  /// Returns true if Google Pay was launched successfully
  static Future<bool> launchGooglePay() async {
    try {
      final result = await _channel.invokeMethod<bool>('launchGooglePay');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
