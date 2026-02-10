import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zen_mode_provider.dart';
import 'zen_mode_active_screen.dart';

/// ─────────────────────────────────────────────
/// Zen Mode Entry Screen
/// Permission checks → Duration selector → Rules → Confirmation
/// ─────────────────────────────────────────────

class ZenModeEntryScreen extends ConsumerStatefulWidget {
  const ZenModeEntryScreen({super.key});

  @override
  ConsumerState<ZenModeEntryScreen> createState() => _ZenModeEntryScreenState();
}

class _ZenModeEntryScreenState extends ConsumerState<ZenModeEntryScreen> {
  int _selectedDuration = 30; // minutes
  bool _showRules = false;
  bool _checkingPermissions = false;

  static const _durations = [20, 30, 60, 120, 180];

  static const _deepBlue = Color(0xFF0A1A44);
  static const _midBlue = Color(0xFF1B2B6B);
  static const _accentBlue = Color(0xFF3D5AFE);
  static const _softWhite = Color(0xFFF0F0F5);

  // Platform channels
  static const _blockerChannel =
      MethodChannel('com.minimalist.launcher/app_blocker');
  static const _dndChannel = MethodChannel('com.minimalist.launcher/dnd');

  @override
  Widget build(BuildContext context) {
    final zen = ref.watch(zenModeProvider);

    // If zen mode is already active, go to active screen
    if (zen.isActive && !zen.hasExpired) {
      return const ZenModeActiveScreen();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A1A44),
              Color(0xFF162255),
              Color(0xFF1B2B6B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Back button ───
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: _softWhite.withValues(alpha: 0.7), size: 20),
                    ),
                  ),
                ),
              ),

              // ─── Main content ───
              Expanded(
                child: _showRules ? _buildRulesPage() : _buildMainPage(zen),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainPage(ZenModeState zen) {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Put down the phone
        Text(
          'Put down the phone',
          style: TextStyle(
            color: _softWhite.withValues(alpha: 0.95),
            fontSize: 30,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enjoy life',
          style: TextStyle(
            color: _softWhite,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Soothe your soul and find balance in your life',
          style: TextStyle(
            color: _softWhite.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),

        const SizedBox(height: 48),

        // ─── Duration selector ───
        GestureDetector(
          onTap: () => _showDurationPicker(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(_selectedDuration),
                  style: TextStyle(
                    color: _softWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: _softWhite.withValues(alpha: 0.6), size: 22),
              ],
            ),
          ),
        ),

        if (zen.sessionsCompleted > 0) ...[
          const SizedBox(height: 14),
          Text(
            '${zen.sessionsCompleted} sessions completed',
            style: TextStyle(
              color: _softWhite.withValues(alpha: 0.3),
              fontSize: 12,
            ),
          ),
        ],

        const Spacer(flex: 3),

        // ─── Start button ───
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GestureDetector(
            onTap: _checkingPermissions
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    _checkAllPermissions();
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _checkingPermissions
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Center(
                child: _checkingPermissions
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFF0A1A44),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Start Zen Mode',
                        style: TextStyle(
                          color: Color(0xFF0A1A44),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildRulesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          Text(
            'Before you start',
            style: TextStyle(
              color: _softWhite,
              fontSize: 26,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Read the rules below carefully:',
            style: TextStyle(
              color: _softWhite.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          // 2×2 rules grid
          Row(
            children: [
              Expanded(
                child: _ruleCard(
                  Icons.warning_amber_rounded,
                  'Zen Mode cannot be\nexited once started',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ruleCard(
                  Icons.notifications_off_rounded,
                  'Incoming notifications\nwill be temporarily muted',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ruleCard(
                  Icons.phone_callback_rounded,
                  'You can still answer\nphone calls and make\nemergency calls',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ruleCard(
                  Icons.lock_rounded,
                  'All apps will be\ntemporarily locked\nexcept the camera',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Duration reminder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined,
                    color: _softWhite.withValues(alpha: 0.5), size: 18),
                const SizedBox(width: 10),
                Text(
                  'Duration: ${_formatDuration(_selectedDuration)}',
                  style: TextStyle(
                    color: _softWhite.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // OK button — actually starts zen mode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.heavyImpact();
                await ref
                    .read(zenModeProvider.notifier)
                    .startZenMode(_selectedDuration);
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ZenModeActiveScreen()),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Center(
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Color(0xFF0A1A44),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // Permission Pre-Check Flow
  // ═══════════════════════════════════════

  /// Check all required permissions before showing rules
  Future<void> _checkAllPermissions() async {
    setState(() => _checkingPermissions = true);

    try {
      // 1. Usage Stats Permission (required for app blocking)
      bool hasUsage = await _blockerChannel.invokeMethod('hasUsageStatsPermission') == true;
      if (!hasUsage) {
        if (!mounted) return;
        await _showPermissionDialog(
          icon: Icons.bar_chart_rounded,
          title: 'Usage Access Required',
          description:
              'Zen Mode needs usage access to detect and block apps.\n\nPlease find "Camel" in the list and enable it.',
          onGrant: () async {
            await _blockerChannel.invokeMethod('requestUsageStatsPermission');
          },
        );
        // Wait a moment for the system settings to register
        await Future.delayed(const Duration(milliseconds: 500));
        hasUsage = await _blockerChannel.invokeMethod('hasUsageStatsPermission') == true;
        if (!hasUsage) {
          _showPermissionWarning('Usage Stats access is required for Zen Mode');
          setState(() => _checkingPermissions = false);
          return;
        }
      }

      // 2. DND Permission (required for muting notifications)
      bool hasDnd = await _dndChannel.invokeMethod('hasDndPermission') == true;
      if (!hasDnd) {
        if (!mounted) return;
        await _showPermissionDialog(
          icon: Icons.notifications_off_rounded,
          title: 'Do Not Disturb Access',
          description:
              'Zen Mode needs DND access to mute all notifications during your session.\n\nPlease find "Camel" and enable it.',
          onGrant: () async {
            await _dndChannel.invokeMethod('requestDndPermission');
          },
        );
        await Future.delayed(const Duration(milliseconds: 500));
        hasDnd = await _dndChannel.invokeMethod('hasDndPermission') == true;
        if (!hasDnd) {
          _showPermissionWarning('DND access is required to mute notifications');
          setState(() => _checkingPermissions = false);
          return;
        }
      }

      // 3. Overlay Permission (required for blocking notification bar)
      bool hasOverlay = await _blockerChannel.invokeMethod('hasOverlayPermission') == true;
      if (!hasOverlay) {
        if (!mounted) return;
        await _showPermissionDialog(
          icon: Icons.layers_rounded,
          title: 'Display Over Other Apps',
          description:
              'Zen Mode needs overlay access to block the notification bar and other apps.\n\nPlease enable "Allow display over other apps".',
          onGrant: () async {
            await _blockerChannel.invokeMethod('requestOverlayPermission');
          },
        );
        await Future.delayed(const Duration(milliseconds: 500));
        hasOverlay = await _blockerChannel.invokeMethod('hasOverlayPermission') == true;
        if (!hasOverlay) {
          _showPermissionWarning('Overlay permission is required for full lockdown');
          setState(() => _checkingPermissions = false);
          return;
        }
      }

      // All permissions granted — show rules page
      if (mounted) {
        setState(() {
          _showRules = true;
          _checkingPermissions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showRules = true;
          _checkingPermissions = false;
        });
      }
    }
  }

  void _showPermissionWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show a permission request dialog with custom icon, title, description
  /// Returns true if user proceeded (after granting), false if cancelled
  Future<bool> _showPermissionDialog({
    required IconData icon,
    required String title,
    required String description,
    required Future<void> Function() onGrant,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accentBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _accentBlue, size: 32),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                style: TextStyle(
                  color: _softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _softWhite.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Grant button
              GestureDetector(
                onTap: () async {
                  await onGrant();
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _accentBlue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      'Grant Permission',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Cancel button
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: _softWhite.withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Widget _ruleCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: _softWhite.withValues(alpha: 0.85), size: 28),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _softWhite.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Duration',
              style: TextStyle(
                color: _softWhite.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ..._durations.map((d) => GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDuration = d);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 18),
                    decoration: BoxDecoration(
                      color: _selectedDuration == d
                          ? _accentBlue.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDuration == d
                            ? _accentBlue.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      _formatDuration(d),
                      style: TextStyle(
                        color: _selectedDuration == d
                            ? _accentBlue
                            : _softWhite.withValues(alpha: 0.7),
                        fontSize: 15,
                        fontWeight: _selectedDuration == d
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int min) {
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }
}
