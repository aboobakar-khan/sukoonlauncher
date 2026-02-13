import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/theme_provider.dart';
import '../providers/premium_provider.dart';
import 'launcher_shell.dart';

/// ═══════════════════════════════════════════════════════════════════
/// ☪️ SUKOON LAUNCHER — PREMIUM ONBOARDING EXPERIENCE
/// ═══════════════════════════════════════════════════════════════════
///
/// A modern, addictive 5-screen onboarding flow.
///
/// Design principles:
///  • Staggered micro-animations — elements appear with choreographed timing
///  • Parallax depth — background layers move at different speeds
///  • Psychology-based UX — hook → pain → solution → value → commitment
///  • Consistent sukoon/desert brand tokens throughout
///  • Responsive layout — adapts to any screen size
///  • Haptic feedback on every interaction
///
/// Screens:
///  1. HOOK — Emotional identity ("Your Phone. Your Rules.")
///  2. IMPACT — Loss aversion with animated stat
///  3. SOLUTION — Product features as the answer
///  4. PRO — Soft upsell with free trial
///  5. ACTIVATE — Set as default launcher
/// ═══════════════════════════════════════════════════════════════════

// ─── Design Tokens ──────────────────────────────────────────────
const Color _bg = Color(0xFF050508);
const Color _cardBg = Color(0xFF0D0D12);
const Color _surfaceBg = Color(0xFF0A0A0F);
const Color _borderDim = Color(0xFF1A1A22);
const Color _gold = Color(0xFFC2A366);
const Color _goldLight = Color(0xFFE8D5B7);
const Color _green = Color(0xFF7BAE6E);
const Color _sunset = Color(0xFFE8915A);
const Color _textPrimary = Color(0xFFF2F0ED);
const Color _textSecondary = Color(0xFF9A9590);
const Color _textMuted = Color(0xFF585450);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 4;

  // Master entrance animation per page
  late AnimationController _entranceController;
  // Pulse for CTA buttons
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  // Floating particles
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _particleController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  // ─── Navigation ───────────────────────────────────────────────

  Future<void> _completeOnboarding() async {
    final box = await Hive.openBox('settingsBox');
    await box.put('onboarding_completed', true);
  }

  void _goToNext() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }



  void _setDefaultAndFinish() async {
    HapticFeedback.heavyImpact();
    try {
      const platform = MethodChannel('com.sukoon.launcher/launcher');
      await platform.invokeMethod('openHomeLauncherSettings');
    } catch (e) {
      debugPrint('Home settings error: $e');
    }
    await _completeOnboarding();
    if (mounted) _navigateToLauncher();
  }

  void _skipToLauncher() async {
    HapticFeedback.lightImpact();
    await _completeOnboarding();
    if (mounted) _navigateToLauncher();
  }

  void _navigateToLauncher() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LauncherShell(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.padding.bottom;
    final topPad = mq.padding.top;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Layer 1: Animated gradient background
          Positioned.fill(child: _GradientBg(page: _currentPage)),

          // Layer 2: Floating particles
          Positioned.fill(
            child: _FloatingParticles(controller: _particleController),
          ),

          // Layer 3: Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(height: topPad > 40 ? 4 : 12),

                // Progress bar + Skip
                _buildTopBar(),

                const SizedBox(height: 8),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (i) {
                      setState(() => _currentPage = i);
                      _entranceController.reset();
                      _entranceController.forward();
                    },
                    children: [
                      _PageHook(entrance: _entranceController),
                      _PageImpact(entrance: _entranceController),
                      _PageSolution(entrance: _entranceController),
                      _PageActivate(
                        entrance: _entranceController,
                        pulse: _pulseAnim,
                      ),
                    ],
                  ),
                ),

                // Bottom CTA
                _buildBottomCTA(),

                SizedBox(height: bottomPad + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════ TOP BAR ═══════════

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      child: Row(
        children: [
          // Segmented progress with glow on active
          Expanded(
            child: Row(
              children: List.generate(_totalPages, (i) {
                final isActive = i <= _currentPage;
                final isCurrent = i == _currentPage;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: isCurrent ? 4 : 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive
                          ? _gold
                          : Colors.white.withValues(alpha: 0.06),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                  color: _gold.withValues(alpha: 0.4),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 20),
          // Skip
          if (_currentPage < _totalPages - 1)
            GestureDetector(
              onTap: _skipToLauncher,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════ BOTTOM CTA ═══════════

  Widget _buildBottomCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _currentPage == 3
            ? _buildActivationButtons()
            : _buildNextButton(),
      ),
    );
  }

  Widget _buildNextButton() {
    final labels = [
      'Begin Your Journey',
      'Show Me the Way',
      'Discover Features',
      'Continue',
    ];
    return _PrimaryCTA(
      key: ValueKey('next_$_currentPage'),
      label: labels[_currentPage],
      onTap: _goToNext,
    );
  }



  Widget _buildActivationButtons() {
    return Column(
      key: const ValueKey('activation_buttons'),
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulseAnim,
          child: _PrimaryCTA(
            label: 'Set as My Launcher',
            onTap: _setDefaultAndFinish,
            icon: Icons.home_rounded,
          ),
        ),
        const SizedBox(height: 10),
        _SecondaryCTA(
            label: "I'll do this later", onTap: _skipToLauncher),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PAGE 1 — HOOK (Identity + Curiosity)
// ═══════════════════════════════════════════════════════════════════

class _PageHook extends StatelessWidget {
  final AnimationController entrance;
  const _PageHook({required this.entrance});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final isSmall = h < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          SizedBox(height: isSmall ? h * 0.06 : h * 0.10),

          // Brand icon with radial glow
          _StaggeredFade(
            entrance: entrance,
            delay: 0.0,
            child: _BrandIcon(size: isSmall ? 80 : 100),
          ),

          SizedBox(height: isSmall ? 28 : 44),

          // Headline
          _StaggeredFade(
            entrance: entrance,
            delay: 0.15,
            child: const Text(
              'Your Phone.\nYour Rules.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.12,
                letterSpacing: -0.8,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Subtext
          _StaggeredFade(
            entrance: entrance,
            delay: 0.30,
            child: Text(
              'Join thousands of mindful Muslims\nwho reclaimed their focus and time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                color: Colors.white.withValues(alpha: 0.48),
                height: 1.65,
                letterSpacing: 0.1,
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Three mini trust chips
          _StaggeredFade(
            entrance: entrance,
            delay: 0.45,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TrustChip(icon: Icons.people_outline, label: '10K+ Users'),
                SizedBox(width: 12),
                _TrustChip(icon: Icons.star_outline, label: '4.8 Rating'),
                SizedBox(width: 12),
                _TrustChip(icon: Icons.verified_outlined, label: 'Ad-Free'),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PAGE 2 — IMPACT (Loss Aversion)
// ═══════════════════════════════════════════════════════════════════

class _PageImpact extends StatelessWidget {
  final AnimationController entrance;
  const _PageImpact({required this.entrance});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final isSmall = h < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          SizedBox(height: isSmall ? h * 0.04 : h * 0.08),

          // Big animated stat
          _StaggeredFade(
            entrance: entrance,
            delay: 0.0,
            child: _AnimatedStat(
              value: 4,
              suffix: ' hrs',
              label: 'Average daily screen time',
              color: _sunset,
            ),
          ),

          SizedBox(height: isSmall ? 24 : 36),

          // Headline
          _StaggeredFade(
            entrance: entrance,
            delay: 0.20,
            child: const Text(
              "That's 60 days\nyou lose every year.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.18,
                letterSpacing: -0.4,
              ),
            ),
          ),

          const SizedBox(height: 18),

          _StaggeredFade(
            entrance: entrance,
            delay: 0.35,
            child: Text(
              '60 days that could be spent in worship,\nwith family, or building your dreams.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.65,
              ),
            ),
          ),

          SizedBox(height: isSmall ? 28 : 44),

          // Time blocks visual
          _StaggeredFade(
            entrance: entrance,
            delay: 0.50,
            child: const _TimeBlockBar(),
          ),

          const SizedBox(height: 14),

          _StaggeredFade(
            entrance: entrance,
            delay: 0.55,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _sunset.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Wasted',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3))),
                const SizedBox(width: 16),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: _green.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text('Reclaimed',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PAGE 3 — SOLUTION (Features)
// ═══════════════════════════════════════════════════════════════════

class _PageSolution extends StatelessWidget {
  final AnimationController entrance;
  const _PageSolution({required this.entrance});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final isSmall = h < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: isSmall ? h * 0.03 : h * 0.06),

          // Headline
          _StaggeredFade(
            entrance: entrance,
            delay: 0.0,
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Everything you need.\n',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextSpan(
                    text: "Nothing you don't.",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _gold,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: isSmall ? 24 : 36),

          // Feature cards
          _StaggeredFade(
            entrance: entrance,
            delay: 0.12,
            child: const _FeatureCard(
              icon: Icons.menu_book_rounded,
              title: 'Quran & Hadith',
              desc: 'Read, reflect, and grow daily',
              accentColor: _green,
            ),
          ),
          const SizedBox(height: 10),
          _StaggeredFade(
            entrance: entrance,
            delay: 0.22,
            child: const _FeatureCard(
              icon: Icons.timer_outlined,
              title: 'Focus & Productivity',
              desc: 'Pomodoro, app blocking, and task lists',
              accentColor: _sunset,
            ),
          ),
          const SizedBox(height: 10),
          _StaggeredFade(
            entrance: entrance,
            delay: 0.32,
            child: const _FeatureCard(
              icon: Icons.favorite_outline_rounded,
              title: 'Prayer & Dhikr',
              desc: 'Track salah, count dhikr, build streaks',
              accentColor: Color(0xFF6BA3D6),
            ),
          ),
          const SizedBox(height: 10),
          _StaggeredFade(
            entrance: entrance,
            delay: 0.42,
            child: const _FeatureCard(
              icon: Icons.palette_outlined,
              title: 'Minimal by Design',
              desc: 'No clutter, no noise — just peace',
              accentColor: Color(0xFFB088C9),
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PAGE 4 — ACTIVATION
// ═══════════════════════════════════════════════════════════════════

class _PageActivate extends StatelessWidget {
  final AnimationController entrance;
  final Animation<double> pulse;
  const _PageActivate({required this.entrance, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final isSmall = h < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(height: isSmall ? h * 0.06 : h * 0.10),

          // Animated home icon
          _StaggeredFade(
            entrance: entrance,
            delay: 0.0,
            child: ScaleTransition(
              scale: pulse,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _gold.withValues(alpha: 0.18),
                      _gold.withValues(alpha: 0.02),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.12),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.home_rounded,
                    size: 44, color: _gold),
              ),
            ),
          ),

          SizedBox(height: isSmall ? 28 : 40),

          _StaggeredFade(
            entrance: entrance,
            delay: 0.12,
            child: const Text(
              'One Last Step',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.12,
              ),
            ),
          ),

          const SizedBox(height: 14),

          _StaggeredFade(
            entrance: entrance,
            delay: 0.22,
            child: Text(
              'Set Sukoon Launcher as your\ndefault home screen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                color: Colors.white.withValues(alpha: 0.48),
                height: 1.6,
              ),
            ),
          ),

          SizedBox(height: isSmall ? 28 : 44),

          // Steps card
          _StaggeredFade(
            entrance: entrance,
            delay: 0.35,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderDim),
              ),
              child: Column(
                children: [
                  const _SetupStepRow(
                      num: '1',
                      text: 'Tap "Set as My Launcher" below'),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                        color:
                            Colors.white.withValues(alpha: 0.04),
                        height: 1),
                  ),
                  const _SetupStepRow(
                      num: '2', text: 'Select "Sukoon Launcher"'),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                        color:
                            Colors.white.withValues(alpha: 0.04),
                        height: 1),
                  ),
                  const _SetupStepRow(
                      num: '3',
                      text: "Press Home — you're done!"),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          _StaggeredFade(
            entrance: entrance,
            delay: 0.50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(width: 6),
                Text(
                  'You can change this anytime in Settings',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  REUSABLE DESIGN COMPONENTS
// ═══════════════════════════════════════════════════════════════════

/// Staggered fade + slide-up entrance animation
class _StaggeredFade extends StatelessWidget {
  final AnimationController entrance;
  final double delay; // 0.0 - 1.0
  final Widget child;

  const _StaggeredFade({
    required this.entrance,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = delay.clamp(0.0, 0.85);
    final end = (delay + 0.35).clamp(0.0, 1.0);

    final opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: entrance,
          curve: Interval(start, end, curve: Curves.easeOut)),
    );
    final slide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(
      CurvedAnimation(
          parent: entrance,
          curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// Brand icon with ambient glow
class _BrandIcon extends StatelessWidget {
  final double size;
  const _BrandIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 40,
      height: size + 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: Text(
            '\u{1F42A}', style: TextStyle(fontSize: size)),
      ),
    );
  }
}

/// Trust chip (page 1)
class _TrustChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _gold.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated stat counter (page 2)
class _AnimatedStat extends StatefulWidget {
  final int value;
  final String suffix;
  final String label;
  final Color color;
  const _AnimatedStat({
    required this.value,
    required this.suffix,
    required this.label,
    required this.color,
  });

  @override
  State<_AnimatedStat> createState() => _AnimatedStatState();
}

class _AnimatedStatState extends State<_AnimatedStat>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _anim =
        Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _anim.value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 76,
                    fontWeight: FontWeight.w900,
                    color: widget.color,
                    height: 1,
                    letterSpacing: -2,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10, left: 4),
                  child: Text(
                    widget.suffix,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: widget.color.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Time blocks bar (page 2 — wasted vs reclaimed)
class _TimeBlockBar extends StatelessWidget {
  const _TimeBlockBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(12, (i) {
        final isWasted = i < 8;
        return AnimatedContainer(
          duration: Duration(milliseconds: 300 + i * 50),
          width: 22,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isWasted
                ? _sunset.withValues(alpha: 0.12 + (i * 0.04))
                : _green.withValues(alpha: 0.10 + ((i - 8) * 0.06)),
            border: Border.all(
              color: isWasted
                  ? _sunset.withValues(alpha: 0.25)
                  : _green.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        );
      }),
    );
  }
}

/// Feature card (page 3)
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color accentColor;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderDim),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.40),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.12), size: 20),
        ],
      ),
    );
  }
}

/// Pro feature row (page 4)
class _ProRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.10)),
          ),
          child: Icon(icon,
              color: _gold.withValues(alpha: 0.85), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Icon(Icons.check_circle_rounded,
            color: _green.withValues(alpha: 0.55), size: 20),
      ],
    );
  }
}

/// Trust pill (page 4 bottom)
class _TrustPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.35),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Setup step row (page 5)
class _SetupStepRow extends StatelessWidget {
  final String num;
  final String text;
  const _SetupStepRow({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gold.withValues(alpha: 0.10),
            border: Border.all(color: _gold.withValues(alpha: 0.18)),
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(
                color: _gold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Primary CTA button
class _PrimaryCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  const _PrimaryCTA({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: _gold,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 20, color: const Color(0xFF1A1000)),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1000),
                    letterSpacing: 0.2,
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

/// Secondary CTA (text link)
class _SecondaryCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ANIMATED BACKGROUND LAYERS
// ═══════════════════════════════════════════════════════════════════

/// Gradient background that morphs per page
class _GradientBg extends StatelessWidget {
  final int page;
  const _GradientBg({required this.page});

  @override
  Widget build(BuildContext context) {
    const gradients = [
      [
        Color(0xFF0A0A1A),
        Color(0xFF0F0A00),
        Color(0xFF050508)
      ], // Hook
      [
        Color(0xFF1A0808),
        Color(0xFF100505),
        Color(0xFF050508)
      ], // Impact
      [
        Color(0xFF061A0A),
        Color(0xFF050F05),
        Color(0xFF050508)
      ], // Solution
      [
        Color(0xFF1A1200),
        Color(0xFF0F0A00),
        Color(0xFF050508)
      ], // Pro
      [
        Color(0xFF0A0F1A),
        Color(0xFF050A10),
        Color(0xFF050508)
      ], // Activate
    ];

    final g = gradients[page.clamp(0, 4)];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.6,
          colors: g,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// Floating particles — subtle ambient effect
class _FloatingParticles extends StatelessWidget {
  final AnimationController controller;
  const _FloatingParticles({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter:
              _ParticlePainter(progress: controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42); // Fixed seed for consistent particles

    for (int i = 0; i < 20; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * math.pi * 2;
      final radius = 1.0 + rng.nextDouble() * 1.5;

      final x =
          baseX +
          math.sin(progress * math.pi * 2 * speed + phase) * 20;
      final y =
          baseY +
          math.cos(progress * math.pi * 2 * speed * 0.7 + phase) *
              15;
      final alpha =
          (0.04 +
              math
                      .sin(progress * math.pi * 2 + phase)
                      .abs() *
                  0.06);

      paint.color = _gold.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress;
}
