import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Debug helper to reset onboarding for testing
/// Usage: Call showDebugResetDialog(context) from anywhere
class DebugResetHelper {
  /// Show dialog to reset onboarding
  static Future<void> showDebugResetDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('🔧 Debug Reset',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reset options for testing:',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            _buildResetButton(
              ctx,
              icon: Icons.play_arrow,
              label: 'Reset Onboarding',
              subtitle: 'Show onboarding on next restart',
              onTap: () async {
                await resetOnboarding();
                Navigator.pop(ctx);
                _showSuccessSnackbar(ctx, 'Onboarding reset! Restart app to test.');
              },
            ),
            const SizedBox(height: 8),
            _buildResetButton(
              ctx,
              icon: Icons.delete_forever,
              label: 'Clear All Data',
              subtitle: 'Delete all Hive boxes (nuclear option)',
              color: Colors.red,
              onTap: () async {
                await clearAllData();
                Navigator.pop(ctx);
                _showSuccessSnackbar(ctx, 'All data cleared! Restart app.');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// Reset onboarding flag only
  static Future<void> resetOnboarding() async {
    final box = await Hive.openBox('app_prefs');
    await box.delete('onboarding_completed');
    await box.close();
  }

  /// Clear all Hive data (nuclear option)
  static Future<void> clearAllData() async {
    try {
      // List all boxes and delete them
      final boxNames = [
        'app_prefs',
        'installed_apps',
        'app_block_rules',
        'productivity_events',
        'productivity_goals',
        'daily_challenges',
        'pomodoro_sessions',
        'read_hadiths',
      ];
      
      for (final name in boxNames) {
        try {
          if (Hive.isBoxOpen(name)) {
            await Hive.box(name).clear();
          } else {
            final box = await Hive.openBox(name);
            await box.clear();
            await box.close();
          }
        } catch (e) {
          // Box might not exist, that's OK
        }
      }
    } catch (e) {
      debugPrint('Error clearing data: $e');
    }
  }

  static Widget _buildResetButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    Color color = const Color(0xFFC2A366),
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Quick access function - Long press anywhere to show debug menu
/// Add this to your main app or launcher shell for easy access
class DebugResetButton extends StatelessWidget {
  const DebugResetButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 20,
      child: GestureDetector(
        onLongPress: () => DebugResetHelper.showDebugResetDialog(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.bug_report, color: Colors.orange, size: 24),
        ),
      ),
    );
  }
}
