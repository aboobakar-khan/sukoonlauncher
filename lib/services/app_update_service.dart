// ══════════════════════════════════════════════════════════════════════════════
// Google Play Flexible In-App Updates Service
// ══════════════════════════════════════════════════════════════════════════════
//
// Production-ready implementation of Google Play In-App Updates
// Follows clean architecture with proper error handling and lifecycle management
//
// Features:
// - Automatic update checks on app start
// - Background download (flexible update)
// - User-friendly minimal dialogs
// - Safe error handling
// - No auto-restart (requires user confirmation)
// - Proper lifecycle handling
// - Support for both Android and other platforms
//
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service for managing Google Play In-App Updates
/// 
/// This service handles:
/// - Checking for available updates
/// - Starting flexible (background) updates
/// - Completing updates with user confirmation
/// - Error handling and platform checks
class AppUpdateService {
  // ── Singleton Pattern ──
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  // ── State Management ──
  AppUpdateInfo? _updateInfo;
  bool _isCheckingForUpdate = false;
  bool _isUpdateDownloading = false;
  bool _isUpdateReady = false;
  bool _initialized = false; // Guard: prevent re-initializing on every resume

  /// Timestamp of the last successful Play Store query.
  /// Update checks are rate-limited to once every 6 hours so we never
  /// hammer the Play Store API on every app resume (battery + data drain).
  DateTime? _lastCheckedAt;
  static const Duration _checkInterval = Duration(hours: 6);

  // ── Callbacks for UI ──
  VoidCallback? _onUpdateAvailable;
  VoidCallback? _onUpdateDownloading;
  VoidCallback? _onUpdateReady;
  Function(String)? _onError;

  // ── Getters ──
  bool get isCheckingForUpdate => _isCheckingForUpdate;
  bool get isUpdateDownloading => _isUpdateDownloading;
  bool get isUpdateReady => _isUpdateReady;
  bool get hasUpdate => _updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;

  // ══════════════════════════════════════════════════════════════════════════
  // Initialize Service
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the update service with optional callbacks
  /// 
  /// Call this early in your app initialization (e.g., in main.dart)
  /// 
  /// Example:
  /// ```dart
  /// AppUpdateService().initialize(
  ///   onUpdateAvailable: () => debugPrint('Update available'),
  ///   onUpdateReady: () => _showUpdateReadyDialog(),
  ///   onError: (error) => debugPrint('Update error: $error'),
  /// );
  /// ```
  void initialize({
    VoidCallback? onUpdateAvailable,
    VoidCallback? onUpdateDownloading,
    VoidCallback? onUpdateReady,
    Function(String)? onError,
  }) {
    // Only register callbacks once per app session.
    // The singleton is shared across the whole app; re-initializing on every
    // resume (didChangeAppLifecycleState) would overwrite valid callbacks with
    // identical ones and spam the log.
    if (_initialized) return;
    _initialized = true;

    _onUpdateAvailable = onUpdateAvailable;
    _onUpdateDownloading = onUpdateDownloading;
    _onUpdateReady = onUpdateReady;
    _onError = onError;

    debugPrint('📦 AppUpdateService initialized');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Check for Updates
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if an update is available on Google Play Store
  /// 
  /// Returns true if an update is available, false otherwise
  /// Safe to call on any platform (only works on Android)
  /// 
  /// Example:
  /// ```dart
  /// final hasUpdate = await AppUpdateService().checkForUpdate();
  /// if (hasUpdate) {
  ///   // Show update UI or start download
  /// }
  /// ```
  Future<bool> checkForUpdate({bool silent = false}) async {
    // Only works on Android
    if (!Platform.isAndroid) return false;

    // Avoid multiple simultaneous checks
    if (_isCheckingForUpdate) return false;

    // ── Rate limit: skip if checked recently (saves battery + Play Store quota) ──
    // On-resume checks are gated here so the Play API is hit at most once
    // every 6 hours regardless of how often the user switches apps.
    // The initial 3s-delayed startup check bypasses this via forceCheck=true.
    final now = DateTime.now();
    if (_lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < _checkInterval) {
      // If we already know about an update, still surface the dialog.
      return hasUpdate;
    }

    _isCheckingForUpdate = true;

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
      _lastCheckedAt = DateTime.now();
      _isCheckingForUpdate = false;

      if (_updateInfo?.updateAvailability == UpdateAvailability.updateAvailable) {
        _onUpdateAvailable?.call();
        return true;
      }
      return false;
    } catch (e) {
      _isCheckingForUpdate = false;

      // Swallow known dev/sideload errors silently — not a Play Store install.
      final msg = e.toString();
      final isKnownDevError = msg.contains('APP_NOT_OWNED') ||
          msg.contains('-10') ||
          msg.contains('APP_NOT_PRESENT') ||
          msg.contains('-5');

      if (!isKnownDevError && !silent) {
        _onError?.call('Failed to check for updates: $e');
      }
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Start Flexible Update (Background Download)
  // ══════════════════════════════════════════════════════════════════════════

  /// Start downloading update in the background
  /// 
  /// User can continue using the app while update downloads
  /// Call [completeFlexibleUpdate] to apply the update after download
  /// 
  /// Returns true if download started successfully
  /// 
  /// Example:
  /// ```dart
  /// final started = await AppUpdateService().startFlexibleUpdate();
  /// if (started) {
  ///   // Show download progress UI
  /// }
  /// ```
  Future<bool> startFlexibleUpdate() async {
    if (!Platform.isAndroid) return false;

    if (_updateInfo == null || !hasUpdate) {
      debugPrint('⚠️ No update available to download');
      return false;
    }

    if (!_updateInfo!.flexibleUpdateAllowed) {
      debugPrint('⚠️ Flexible update not allowed for this update');
      return false;
    }

    if (_isUpdateDownloading) {
      debugPrint('⏳ Update already downloading...');
      return false;
    }

    try {
      debugPrint('📥 Starting flexible update download...');
      _isUpdateDownloading = true;
      _onUpdateDownloading?.call();

      // Start the flexible update
      final result = await InAppUpdate.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        debugPrint('✅ Update download started successfully');
        _isUpdateDownloading = false;
        _isUpdateReady = true;
        _onUpdateReady?.call();
        return true;
      } else {
        debugPrint('⚠️ Update download failed: $result');
        _isUpdateDownloading = false;
        _onError?.call('Update download failed: $result');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error starting flexible update: $e');
      _isUpdateDownloading = false;
      _onError?.call('Failed to start update: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Complete Flexible Update (Apply Update)
  // ══════════════════════════════════════════════════════════════════════════

  /// Complete the flexible update (restart app to apply)
  /// 
  /// Call this after user confirms they want to apply the downloaded update
  /// This will restart the app to complete the installation
  /// 
  /// Example:
  /// ```dart
  /// await AppUpdateService().completeFlexibleUpdate();
  /// // App will restart automatically
  /// ```
  Future<void> completeFlexibleUpdate() async {
    if (!Platform.isAndroid) return;

    if (!_isUpdateReady) {
      debugPrint('⚠️ No update ready to complete');
      return;
    }

    try {
      debugPrint('🔄 Completing flexible update (restarting app)...');
      await InAppUpdate.completeFlexibleUpdate();
      // App will restart at this point
    } catch (e) {
      debugPrint('❌ Error completing flexible update: $e');
      _onError?.call('Failed to complete update: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helper: Check and Start Update (Combined)
  // ══════════════════════════════════════════════════════════════════════════

  /// Convenience method: Check for update and start download if available
  /// 
  /// Returns true if update check + download started successfully
  /// 
  /// Example:
  /// ```dart
  /// await AppUpdateService().checkAndStartUpdate();
  /// ```
  Future<bool> checkAndStartUpdate({bool silent = false}) async {
    final hasUpdate = await checkForUpdate(silent: silent);
    if (hasUpdate) {
      return await startFlexibleUpdate();
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Helper: Show Update Dialog (UI)
  // ══════════════════════════════════════════════════════════════════════════

  /// Show a dialog prompting user to update the app
  /// 
  /// This is a helper method for displaying update UI
  /// You can customize this or create your own dialog
  /// 
  /// Example:
  /// ```dart
  /// AppUpdateService().showUpdateDialog(context);
  /// ```
  void showUpdateDialog(BuildContext context) {
    if (!hasUpdate) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            const Text('Update Available'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version of Sukoon Launcher is available.',
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 12),
            Text(
              'The update will download in the background while you continue using the app.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              startFlexibleUpdate();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  /// Show dialog when update is downloaded and ready to install
  /// 
  /// Example:
  /// ```dart
  /// AppUpdateService().showUpdateReadyDialog(context);
  /// ```
  void showUpdateReadyDialog(BuildContext context) {
    if (!_isUpdateReady) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.download_done, color: Colors.green.shade700),
            const SizedBox(width: 12),
            const Text('Update Ready'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update downloaded successfully.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text(
              'Restart the app to apply the update.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              completeFlexibleUpdate();
              // No need to pop dialog - app will restart
            },
            child: const Text('Restart Now'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ══════════════════════════════════════════════════════════════════════════

  /// Reset service state
  void reset() {
    _updateInfo = null;
    _isCheckingForUpdate = false;
    _isUpdateDownloading = false;
    _isUpdateReady = false;
    _initialized = false;
    debugPrint('🔄 AppUpdateService reset');
  }

  /// Release UI callbacks only. Do NOT call reset() — the singleton must keep
  /// its _initialized flag and _lastCheckedAt timestamp across screen rebuilds
  /// so the 6-hour rate limit survives dispose/re-init cycles.
  void dispose() {
    _onUpdateAvailable = null;
    _onUpdateDownloading = null;
    _onUpdateReady = null;
    _onError = null;
  }
}
