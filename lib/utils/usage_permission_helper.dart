import 'package:flutter/material.dart';
import '../services/native_app_blocker_service.dart';

/// Shows a Usage Access permission dialog if the user hasn't granted it yet.
///
/// Returns `true`  — permission is already granted OR user just granted it.
/// Returns `false` — user cancelled / denied (caller should abort the action).
class UsagePermissionHelper {
  UsagePermissionHelper._();

  /// Checks Usage Access permission.
  /// If not granted, shows a dialog explaining why it's needed and opens
  /// the system settings page so the user can grant it.
  ///
  /// [context] — any mounted BuildContext.
  /// Returns `true` if permission is available after this call.
  static Future<bool> ensureGranted(BuildContext context) async {
    // Already granted — nothing to do
    if (await NativeAppBlockerService.hasUsageStatsPermission()) return true;

    if (!context.mounted) return false;

    final accent = Theme.of(context).colorScheme.primary;

    final tapped = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer_outlined, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Permission Needed',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        content: Text(
          'App Timer (Precision Mode) needs "Usage Access" to detect which app is open and enforce your time limits.\n\nTap "Grant Access" → find Sukoon → turn it on.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not Now',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await NativeAppBlockerService.requestUsageStatsPermission();
            },
            child: Text(
              'Grant Access',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (tapped != true) return false;

    // User tapped "Grant Access" — give them a moment to return from settings,
    // then check again.
    await Future.delayed(const Duration(milliseconds: 800));
    return NativeAppBlockerService.hasUsageStatsPermission();
  }
}
