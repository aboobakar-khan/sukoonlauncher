import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/theme_provider.dart';
import '../providers/premium_provider.dart';
import 'launcher_shell.dart';

/// ═══════════════════════════════════════════════════════════════════
/// 🐪 CAMEL LAUNCHER — PROFESSIONAL ONBOARDING
/// ═══════════════════════════════════════════════════════════════════
///
/// Psychology-based 5-screen onboarding flow:
///
///  1. HOOK        — Emotional connection, identity ("You're different")
///  2. PAIN POINT  — Mirror their frustration with phone addiction
///  3. SOLUTION    — Show the product as the answer
///  4. SOCIAL PROOF + PRO — Build trust + upsell naturally
///  5. ACTIVATION  — Set as default launcher (commitment step)
///
/// Principles applied:
///  • Zeigarnik Effect — Progress bar creates completion drive
///  • Loss Aversion   — Frame around what they're losing (time, focus)
///  • Endowment Effect — "Your minimalist home screen" (ownership)
///  • Identity Framing — "You're the kind of person who…"
///  • Reciprocity      — Give value first, ask for upgrade after
///  • Anchoring        — Show yearly price after lifetime
/// ═══════════════════════════════════════════════════════════════════

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  // ───────── Navigation ─────────

  Future<void> _completeOnboarding() async {
    final box = await Hive.openBox('settingsBox');
    await box.put('onboarding_completed', true);
  }

  void _goToNext() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _activateTrialAndContinue() async {
    HapticFeedback.mediumImpact();
    await ref.read(premiumProvider.notifier).startFreeTrial();
    _goToNext();
  }

  void _setDefaultAndFinish() async {
    HapticFeedback.heavyImpact();
    try {
      const platform = MethodChannel('com.example.minimalist_app/launcher');
      await platform.invokeMethod('openHomeLauncherSettings');
    } catch (e) {
      debugPrint('Home settings error: $e');
    }
    await _completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LauncherShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _skipToLauncher() async {
    HapticFeedback.lightImpact();
    await _completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LauncherShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  // ───────── BUILD ─────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Subtle radial gradient background
          Positioned.fill(
            child: _AnimatedGradientBg(page: _currentPage),
          ),

          // Main content
          Column(
            children: [
              SizedBox(height: screenH * 0.06),

              // Top bar: progress + skip
              _buildTopBar(),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    _fadeController.reset();
                    _fadeController.forward();
                  },
                  children: [
                    _page1Hook(),
                    _page2PainPoint(),
                    _page3Solution(),
                    _page4ProUpsell(),
                    _page5Activation(),
                  ],
                ),
              ),

              // Bottom CTA
              _buildBottomCTA(),

              SizedBox(height: bottomPad + 16),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════ TOP BAR ═══════════

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Segmented progress bar
          Expanded(child: _buildProgressBar()),
          const SizedBox(width: 16),
          // Skip (not on last page)
          if (_currentPage < _totalPages - 1)
            GestureDetector(
              onTap: _skipToLauncher,
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(_totalPages, (i) {
        final isActive = i <= _currentPage;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive
                  ? CamelColors.sandGold
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
        );
      }),
    );
  }

  // ═══════════ BOTTOM CTA ═══════════

  Widget _buildBottomCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _currentPage == 3
            ? _buildProButtons()
            : _currentPage == 4
                ? _buildActivationButtons()
                : _buildNextButton(),
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      key: ValueKey('next_$_currentPage'),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _goToNext,
        style: ElevatedButton.styleFrom(
          backgroundColor: CamelColors.sandGold,
          foregroundColor: const Color(0xFF1A1000),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _currentPage == 0
              ? 'Begin Your Journey'
              : _currentPage == 1
                  ? 'Show Me the Way'
                  : 'Continue',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildProButtons() {
    return Column(
      key: const ValueKey('pro_buttons'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary: Start free trial
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _activateTrialAndContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: CamelColors.sandGold,
              foregroundColor: const Color(0xFF1A1000),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Start 7-Day Free Trial',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary: skip
        GestureDetector(
          onTap: _goToNext,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Maybe later',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivationButtons() {
    return Column(
      key: const ValueKey('activation_buttons'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary: Set as default
        ScaleTransition(
          scale: _pulseAnimation,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _setDefaultAndFinish,
              style: ElevatedButton.styleFrom(
                backgroundColor: CamelColors.sandGold,
                foregroundColor: const Color(0xFF1A1000),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_rounded, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Set as My Launcher',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary: not now
        GestureDetector(
          onTap: _skipToLauncher,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'I\'ll do this later',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  PAGE 1 — HOOK (Identity + Curiosity)
  // ═══════════════════════════════════════════════════

  Widget _page1Hook() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Elegant icon
            _GlowingIcon(
              icon: '🐪',
              size: 100,
              glowColor: CamelColors.sandGold,
            ),

            const SizedBox(height: 48),

            // Identity hook headline
            const Text(
              'Your Phone.\nYour Rules.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 20),

            // Subtext — aspirational
            Text(
              'Join thousands of Muslims who chose\na mindful, distraction-free phone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  PAGE 2 — PAIN POINT (Loss Aversion)
  // ═══════════════════════════════════════════════════

  Widget _page2PainPoint() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Shocking stat
            _AnimatedCounter(
              targetNumber: 4,
              suffix: 'hrs',
              label: 'Average daily screen time',
              color: CamelColors.desertSunset,
            ),

            const SizedBox(height: 40),

            // Emotional headline
            const Text(
              'That\'s 60 days\nyou lose every year.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              '60 days that could be spent in worship,\nwith family, or building your dreams.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 40),

            // Visual: time blocks lost
            _TimeBlocksVisual(),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  PAGE 3 — SOLUTION (Product as the Answer)
  // ═══════════════════════════════════════════════════

  Widget _page3Solution() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Headline
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'Everything you need.\n',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  TextSpan(
                    text: 'Nothing you don\'t.',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: CamelColors.sandGold,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 44),

            // Feature cards — modern glass style
            const _FeatureCard(
              icon: Icons.menu_book_rounded,
              title: 'Quran & Hadith',
              desc: 'Read, reflect, and grow daily',
              color: Color(0xFF2D5A27),
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              icon: Icons.timer_outlined,
              title: 'Focus & Productivity',
              desc: 'Pomodoro, app blocking, and todo lists',
              color: Color(0xFF4A3728),
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              icon: Icons.favorite_border_rounded,
              title: 'Prayer & Dhikr',
              desc: 'Track salah, count dhikr, build habits',
              color: Color(0xFF1E3A5F),
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              icon: Icons.palette_outlined,
              title: 'Minimal by Design',
              desc: 'No clutter, no noise — just peace',
              color: Color(0xFF3D2E4F),
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  PAGE 4 — PRO UPSELL (Soft, Value-First)
  // ═══════════════════════════════════════════════════

  Widget _page4ProUpsell() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Pro badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CamelColors.sandGold.withValues(alpha: 0.15),
                    CamelColors.desertWarm.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: CamelColors.sandGold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: CamelColors.sandGold, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'CAMEL PRO',
                    style: TextStyle(
                      color: CamelColors.sandGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Headline
            const Text(
              'Unlock Your\nFull Potential',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 36),

            // Pro features — clean checklist
            _ProFeatureRow(icon: Icons.color_lens_outlined, text: 'All themes & clock styles'),
            const SizedBox(height: 16),
            _ProFeatureRow(icon: Icons.mosque_outlined, text: 'Full Dua library & Tafseer'),
            const SizedBox(height: 16),
            _ProFeatureRow(icon: Icons.shield_outlined, text: 'Deen Mode & Hard Block'),
            const SizedBox(height: 16),
            _ProFeatureRow(icon: Icons.analytics_outlined, text: 'Advanced statistics & dashboards'),
            const SizedBox(height: 16),
            _ProFeatureRow(icon: Icons.cloud_outlined, text: 'Cloud backup & data export'),
            const SizedBox(height: 16),
            _ProFeatureRow(icon: Icons.auto_awesome, text: 'Priority support & updates'),

            const SizedBox(height: 36),

            // Trust badges
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TrustBadge(icon: Icons.lock_outline, label: 'Cancel\nanytime'),
                SizedBox(width: 24),
                _TrustBadge(icon: Icons.credit_card_off_outlined, label: 'No charge\nfor 7 days'),
                SizedBox(width: 24),
                _TrustBadge(icon: Icons.verified_outlined, label: 'Secure\npayment'),
              ],
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  PAGE 5 — ACTIVATION (Default Launcher CTA)
  // ═══════════════════════════════════════════════════

  Widget _page5Activation() {
    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Animated home icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      CamelColors.sandGold.withValues(alpha: 0.2),
                      CamelColors.sandGold.withValues(alpha: 0.03),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 48,
                  color: CamelColors.sandGold,
                ),
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              'One Last Step',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Set Camel Launcher as your\ndefault home screen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 44),

            // Steps — minimal
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                children: [
                  const _StepRow(number: '1', text: 'Tap "Set as My Launcher" below'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                  ),
                  const _StepRow(number: '2', text: 'Select "Camel Launcher"'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.06),
                      height: 1,
                    ),
                  ),
                  const _StepRow(number: '3', text: 'Press the Home button — done!'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Reassurance
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 8),
                Text(
                  'You can change this anytime in Settings',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),

            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  REUSABLE COMPONENTS
// ═══════════════════════════════════════════════════════════════

/// Animated gradient background that shifts per page
class _AnimatedGradientBg extends StatelessWidget {
  final int page;
  const _AnimatedGradientBg({required this.page});

  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFF0A0A1A), const Color(0xFF0F0A00)],
      [const Color(0xFF1A0505), const Color(0xFF0A0A0F)],
      [const Color(0xFF051A0A), const Color(0xFF0A0A0F)],
      [const Color(0xFF1A1200), const Color(0xFF0A0A0F)],
      [const Color(0xFF0A0F1A), const Color(0xFF0A0A0F)],
    ];

    final c = colors[page.clamp(0, 4)];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [c[0], c[1]],
        ),
      ),
    );
  }
}

/// Emoji with soft glow effect
class _GlowingIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color glowColor;
  const _GlowingIcon({required this.icon, required this.size, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 40,
      height: size + 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.15),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: Text(icon, style: TextStyle(fontSize: size)),
      ),
    );
  }
}

/// Animated number counter for shock stat
class _AnimatedCounter extends StatefulWidget {
  final int targetNumber;
  final String suffix;
  final String label;
  final Color color;
  const _AnimatedCounter({
    required this.targetNumber,
    required this.suffix,
    required this.label,
    required this.color,
  });

  @override
  State<_AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<_AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.targetNumber.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _animation.value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: widget.color,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    widget.suffix,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: widget.color.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Visual time blocks (showing wasted time)
class _TimeBlocksVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(12, (i) {
          final isWasted = i < 8;
          return Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isWasted
                  ? CamelColors.desertSunset.withValues(alpha: 0.15 + (i * 0.05))
                  : CamelColors.oasisGreen.withValues(alpha: 0.12),
              border: Border.all(
                color: isWasted
                    ? CamelColors.desertSunset.withValues(alpha: 0.3)
                    : CamelColors.oasisGreen.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Feature card — modern glass style
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
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
                    color: Colors.white,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pro feature row with check
class _ProFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ProFeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CamelColors.sandGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: CamelColors.sandGold, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Icon(Icons.check_circle_rounded,
            color: CamelColors.oasisGreen.withValues(alpha: 0.6), size: 20),
      ],
    );
  }
}

/// Trust badge
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.35),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Step row for activation page
class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CamelColors.sandGold.withValues(alpha: 0.12),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: CamelColors.sandGold,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
