import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zen_mode_provider.dart';
import '../providers/theme_provider.dart';
import 'zen_mode_active_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Zen Mode Permissions Screen
/// Beautiful step-by-step permission flow — ask only what's needed
/// Auto-advances after each grant; shows live status for each permission
/// ─────────────────────────────────────────────────────────────────────────────

enum _PermStatus { waiting, checking, granted, denied }

class _PermItem {
  final String id;
  final IconData icon;
  final String title;
  final String why;
  final String hint;
  _PermStatus status = _PermStatus.waiting;

  _PermItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.why,
    required this.hint,
  });
}

class ZenModePermissionsScreen extends ConsumerStatefulWidget {
  final int durationMinutes;
  const ZenModePermissionsScreen({super.key, required this.durationMinutes});

  @override
  ConsumerState<ZenModePermissionsScreen> createState() =>
      _ZenModePermissionsScreenState();
}

class _ZenModePermissionsScreenState
    extends ConsumerState<ZenModePermissionsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _blockerChannel =
      MethodChannel('com.sukoon.launcher/app_blocker');
  static const _dndChannel = MethodChannel('com.sukoon.launcher/dnd');

  late List<_PermItem> _perms;
  int _currentIndex = 0;
  bool _isChecking = false;
  bool _allGranted = false;

  late AnimationController _slideCtrl;
  late AnimationController _checkCtrl;
  late Animation<double> _scaleAnim;

  static const _bg = Color(0xFF080E1A);
  static const _card = Color(0xFF0F1829);
  static const _border = Color(0xFF1C2A42);

  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _sageLight => _sage.withValues(alpha: 0.85);
  static const _amber = Color(0xFFD4A853);
  static const _red = Color(0xFFD45C5C);

  @override
  void initState() {
    super.initState();
    _perms = [
      _PermItem(
        id: 'usage',
        icon: Icons.bar_chart_rounded,
        title: 'Usage Access',
        why: 'Lets Muraqaba detect and block all other apps — the core of focus.',
        hint: 'Open Settings → Special App Access → Usage Access → Enable Sukoon',
      ),
      _PermItem(
        id: 'overlay',
        icon: Icons.layers_rounded,
        title: 'Display Over Other Apps',
        why: 'Blocks notification bars and pop-ups from breaking your focus.',
        hint: 'Open Settings → Special App Access → Display Over Other Apps → Enable Sukoon',
      ),
      _PermItem(
        id: 'dnd',
        icon: Icons.notifications_off_rounded,
        title: 'Do Not Disturb',
        why: 'Silences all calls and alerts so nothing interrupts your session.',
        hint: 'Open Settings → Special App Access → Do Not Disturb → Enable Sukoon',
      ),
    ];

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _checkCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut));

    _slideCtrl.forward();
    WidgetsBinding.instance.addObserver(this);
    _checkAllStatusOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slideCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  /// Called whenever the app comes back to foreground — re-check the current permission
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed && _isChecking) {
      _verifyCurrentPermission();
    }
  }

  /// On open, quietly check which permissions are already granted
  Future<void> _checkAllStatusOnStart() async {
    final usage =
        await _blockerChannel.invokeMethod('hasUsageStatsPermission') == true;
    final overlay =
        await _blockerChannel.invokeMethod('hasOverlayPermission') == true;
    final dnd = await _dndChannel.invokeMethod('hasDndPermission') == true;

    final statuses = [usage, overlay, dnd];
    setState(() {
      for (int i = 0; i < _perms.length; i++) {
        _perms[i].status =
            statuses[i] ? _PermStatus.granted : _PermStatus.waiting;
      }
      // Find first non-granted
      _currentIndex = _perms.indexWhere((p) => p.status != _PermStatus.granted);
      if (_currentIndex == -1) {
        _allGranted = true;
        _currentIndex = _perms.length - 1;
      }
    });
  }

  Future<void> _requestCurrent() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
      _perms[_currentIndex].status = _PermStatus.checking;
    });
    HapticFeedback.mediumImpact();

    final perm = _perms[_currentIndex];

    // Open system settings for this specific permission
    try {
      switch (perm.id) {
        case 'usage':
          await _blockerChannel.invokeMethod('requestUsageStatsPermission');
          break;
        case 'overlay':
          await _blockerChannel.invokeMethod('requestOverlayPermission');
          break;
        case 'dnd':
          await _dndChannel.invokeMethod('requestDndPermission');
          break;
      }
    } catch (_) {}

    // _isChecking stays true — didChangeAppLifecycleState will call
    // _verifyCurrentPermission() when the user returns from settings.
  }

  Future<void> _verifyCurrentPermission() async {
    bool granted = false;
    final perm = _perms[_currentIndex];
    try {
      switch (perm.id) {
        case 'usage':
          granted =
              await _blockerChannel.invokeMethod('hasUsageStatsPermission') ==
                  true;
          break;
        case 'overlay':
          granted =
              await _blockerChannel.invokeMethod('hasOverlayPermission') == true;
          break;
        case 'dnd':
          granted =
              await _dndChannel.invokeMethod('hasDndPermission') == true;
          break;
      }
    } catch (_) {}

    setState(() {
      _perms[_currentIndex].status =
          granted ? _PermStatus.granted : _PermStatus.denied;
      _isChecking = false;
    });

    if (granted) {
      HapticFeedback.lightImpact();
      _checkCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 700));
      _advanceToNext();
    }
  }

  void _advanceToNext() {
    final nextIndex =
        _perms.indexWhere((p) => p.status != _PermStatus.granted);
    if (nextIndex == -1) {
      setState(() => _allGranted = true);
      _checkCtrl.forward(from: 0);
    } else {
      setState(() => _currentIndex = nextIndex);
      _slideCtrl.forward(from: 0);
    }
  }

  void _proceedToEmergency() {
    HapticFeedback.heavyImpact();
    _startZenSession();
  }

  Future<void> _startZenSession() async {
    await ref.read(zenModeProvider.notifier).startZenMode(widget.durationMinutes);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const ZenModeActiveScreen(),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildHeader(),
                    const SizedBox(height: 36),
                    _buildPermissionsList(),
                    const SizedBox(height: 32),
                    _buildActionArea(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white54, size: 18),
            ),
          ),
          const Spacer(),
          // Step indicator
          Row(
            children: List.generate(
              _perms.length,
              (i) {
                final status = _perms[i].status;
                final isActive = i == _currentIndex && !_allGranted;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: status == _PermStatus.granted
                        ? _sage
                        : isActive
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.15),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon cluster
        SizedBox(
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _sage.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _sage.withValues(alpha: 0.12),
                  border: Border.all(color: _sage.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.shield_outlined,
                    color: _sageLight, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Permissions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Muraqaba needs 3 permissions to fully\nprotect your focus. All are revokable anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsList() {
    return Column(
      children: List.generate(_perms.length, (i) {
        final perm = _perms[i];
        final isActive = i == _currentIndex && !_allGranted;
        final isGranted = perm.status == _PermStatus.granted;
        final isDenied = perm.status == _PermStatus.denied;
        final isChecking = perm.status == _PermStatus.checking;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isGranted
                ? _sage.withValues(alpha: 0.07)
                : isActive
                    ? _card
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isGranted
                  ? _sage.withValues(alpha: 0.3)
                  : isActive
                      ? _border
                      : _border.withValues(alpha: 0.4),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Status icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isGranted
                    ? ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          key: ValueKey('granted_$i'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sage.withValues(alpha: 0.15),
                            border: Border.all(
                                color: _sage.withValues(alpha: 0.4)),
                          ),
                          child: Icon(Icons.check_rounded,
                              color: _sageLight, size: 20),
                        ),
                      )
                    : isChecking
                        ? Container(
                            key: ValueKey('checking_$i'),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _amber.withValues(alpha: 0.1),
                              border: Border.all(
                                  color: _amber.withValues(alpha: 0.3)),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _amber,
                              ),
                            ),
                          )
                        : Container(
                            key: ValueKey('icon_$i'),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDenied
                                  ? _red.withValues(alpha: 0.1)
                                  : isActive
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.white.withValues(alpha: 0.03),
                              border: Border.all(
                                color: isDenied
                                    ? _red.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Icon(
                              perm.icon,
                              color: isDenied
                                  ? _red
                                  : isActive
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.white.withValues(alpha: 0.25),
                              size: 20,
                            ),
                          ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perm.title,
                      style: TextStyle(
                        color: isGranted
                            ? _sageLight
                            : isActive
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.35),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isGranted
                          ? 'Granted ✓'
                          : isDenied
                              ? 'Not granted — try again'
                              : perm.why,
                      style: TextStyle(
                        color: isGranted
                            ? _sage.withValues(alpha: 0.7)
                            : isDenied
                                ? _red.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.35),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isGranted && isActive) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 18),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionArea() {
    if (_allGranted) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: _sage.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _sage.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    color: _sageLight, size: 18),
                const SizedBox(width: 8),
                Text(
                  'All permissions granted',
                  style: TextStyle(
                      color: _sageLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _bigButton(
            label: 'Continue →',
            color: _sage,
            onTap: _proceedToEmergency,
          ),
        ],
      );
    }

    final perm = _perms[_currentIndex];
    final isDenied = perm.status == _PermStatus.denied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint box
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey(_currentIndex),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.25), size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    perm.hint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _bigButton(
          label: isDenied ? 'Try Again' : 'Grant ${perm.title}',
          color: isDenied ? _amber : Colors.white,
          textColor: isDenied ? Colors.black87 : const Color(0xFF080E1A),
          onTap: _isChecking ? null : _requestCurrent,
          isLoading: _isChecking,
        ),
        if (_allPermissionsCanSkip()) ...[
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: _proceedToEmergency,
              child: Text(
                'Skip for now →',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _allPermissionsCanSkip() {
    return _perms.every((p) =>
        p.status == _PermStatus.granted || p.status == _PermStatus.denied);
  }

  Widget _bigButton({
    required String label,
    required Color color,
    Color? textColor,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null && !isLoading ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor ?? const Color(0xFF080E1A),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: textColor ?? const Color(0xFF080E1A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
