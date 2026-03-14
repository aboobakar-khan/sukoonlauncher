import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../services/offline_content_manager.dart';
import 'launcher_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WarmupScreen
//
//  Shown ONCE — right after the user finishes onboarding.
//  During the animation we:
//    1. Fetch the full installed-apps list from the OS (slow syscall).
//    2. Warm up prayer-times, favorites, offline content, and theme providers.
//    3. Run at least [_kMinDuration] so the animation is never truncated.
//
//  When all work is done the screen fades into LauncherShell.
// ─────────────────────────────────────────────────────────────────────────────

class WarmupScreen extends ConsumerStatefulWidget {
  const WarmupScreen({super.key});

  @override
  ConsumerState<WarmupScreen> createState() => _WarmupScreenState();
}

class _WarmupScreenState extends ConsumerState<WarmupScreen>
    with TickerProviderStateMixin {
  // ── minimum time the screen stays visible (aesthetic floor) ──
  static const _kMinDuration = Duration(seconds: 3);

  // ── Progress ring ──
  late AnimationController _ringCtrl;
  late Animation<double> _ringProgress; // 0 → 1

  // ── Ambient pulse behind the ring ──
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  // ── Text fade ──
  late AnimationController _textCtrl;
  late Animation<double> _textFade;

  // ── Exit fade ──
  late AnimationController _exitCtrl;
  late Animation<double> _exitFade;

  // Rotating status messages shown during warmup
  static const _messages = [
    'Personalising your experience…',
    'Loading your apps…',
    'Setting up prayer times…',
    'Preparing your space…',
    'Almost there…',
  ];
  int _msgIndex = 0;

  bool _workDone = false;
  bool _minTimeDone = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // ── Ring fills from 0 → 1 over the min duration ──
    _ringCtrl = AnimationController(vsync: this, duration: _kMinDuration);
    _ringProgress = CurvedAnimation(
      parent: _ringCtrl,
      curve: Curves.easeInOut,
    );

    // ── Pulse loops forever ──
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.10, end: 0.22).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ── Text fades in ──
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    // ── Exit: opacity 1 → 0 ──
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn),
    );

    // Rotate message every 800 ms
    _startMessageRotation();

    // Start all background work in parallel
    _ringCtrl.forward().whenComplete(() {
      _minTimeDone = true;
      _maybeNavigate();
    });
    _runWarmup();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  // ── Rotate status messages ─────────────────────────────────────────────────
  void _startMessageRotation() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _textCtrl.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() {
          _msgIndex = (_msgIndex + 1) % _messages.length;
        });
        _textCtrl.forward();
        _startMessageRotation();
      });
    });
  }

  // ── Background warmup work ─────────────────────────────────────────────────
  Future<void> _runWarmup() async {
    await Future.wait([
      // 1. Fetch installed apps — the heaviest call (OS scan)
      ref.read(installedAppsProvider.notifier).refreshApps(),
      // 2. Touch other providers to trigger their lazy init
      Future.microtask(() => ref.read(favoriteAppsProvider)),
      Future.microtask(() => ref.read(themeColorProvider)),
      Future.microtask(() => ref.read(offlineContentProvider)),
    ]);
    _workDone = true;
    _maybeNavigate();
  }

  // ── Only navigate when BOTH the min time AND the work are done ────────────
  void _maybeNavigate() {
    if (!_workDone || !_minTimeDone) return;
    if (!mounted) return;
    _exitCtrl.forward().whenComplete(_goToLauncher);
  }

  void _goToLauncher() {
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LauncherShell(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exitFade,
      builder: (context, child) => Opacity(
        opacity: _exitFade.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF080808),
        body: Center(
          child: FadeTransition(
            opacity: _textFade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated ring ──────────────────────────────────────────
                SizedBox(
                  width: 120,
                  height: 120,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_ringProgress, _pulseCtrl]),
                    builder: (_, __) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ambient glow disc
                          Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6B8F71)
                                    .withValues(alpha: _pulseOpacity.value),
                              ),
                            ),
                          ),
                          // Track ring (dimmed)
                          CustomPaint(
                            size: const Size(110, 110),
                            painter: _RingPainter(
                              progress: 1.0,
                              color: const Color(0xFF6B8F71)
                                  .withValues(alpha: 0.12),
                              strokeWidth: 2.5,
                            ),
                          ),
                          // Progress ring
                          CustomPaint(
                            size: const Size(110, 110),
                            painter: _RingPainter(
                              progress: _ringProgress.value,
                              color: const Color(0xFF6B8F71),
                              strokeWidth: 2.5,
                            ),
                          ),
                          // Centre logo / icon
                          Icon(
                            Icons.spa_outlined,
                            size: 32,
                            color: const Color(0xFF6B8F71)
                                .withValues(alpha: 0.80),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // ── Heading ────────────────────────────────────────────────
                const Text(
                  'Sukoon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 6,
                    decoration: TextDecoration.none,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Rotating status message ───────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _messages[_msgIndex],
                    key: ValueKey(_msgIndex),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.6,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ring painter — draws a circular arc from the top, clockwise
// ─────────────────────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2,
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,           // start at top
      2 * math.pi * progress, // sweep clockwise
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
