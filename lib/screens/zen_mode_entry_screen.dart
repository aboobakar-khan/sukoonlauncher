import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zen_mode_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/swipe_back_wrapper.dart';
import 'zen_mode_active_screen.dart';
import 'zen_mode_permissions_screen.dart';
import 'premium_paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Zen Mode Entry Screen
// Beautiful pre-zen briefing: What is it, how long, what happens
// Leads to Permissions → Emergency Contacts → Active
// ─────────────────────────────────────────────────────────────────────────────

class ZenModeEntryScreen extends ConsumerStatefulWidget {
  const ZenModeEntryScreen({super.key});

  @override
  ConsumerState<ZenModeEntryScreen> createState() => _ZenModeEntryScreenState();
}

class _ZenModeEntryScreenState extends ConsumerState<ZenModeEntryScreen>
    with TickerProviderStateMixin {
  int _selectedMinutes = 30;
  late AnimationController _breatheCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _breatheAnim;

  static const _bg = Color(0xFF080E1A);
  static const _card = Color(0xFF0F1829);
  static const _border = Color(0xFF1C2A42);

  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _sageLight => _sage.withValues(alpha: 0.85);
  Color get _sageDim => Color.lerp(_sage, const Color(0xFF000000), 0.35)!;

  static const _presets = [15, 20, 30, 45, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _breatheAnim =
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int min) {
    if (min < 60) return '$min min';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  void _showCustomDurationPicker() {
    int hours = _selectedMinutes ~/ 60;
    int minutes = _selectedMinutes % 60;
    // Round minutes to nearest 5
    minutes = (minutes / 5).round() * 5;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1829),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Custom Duration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildNumberPicker(
                    value: hours,
                    min: 0,
                    max: 12,
                    label: 'hr',
                    onChanged: (v) => setModalState(() => hours = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  _buildNumberPicker(
                    value: minutes,
                    min: 0,
                    max: 55,
                    step: 5,
                    label: 'min',
                    onChanged: (v) => setModalState(() => minutes = v),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  final total = hours * 60 + minutes;
                  if (total < 5) return;
                  setState(() => _selectedMinutes = total);
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _sage,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Center(
                    child: Text(
                      'Set Duration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
  }

  Widget _buildNumberPicker({
    required int value,
    required int min,
    required int max,
    required String label,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1C2A42)),
          ),
          child: ListWheelScrollView.useDelegate(
            itemExtent: 44,
            perspective: 0.003,
            physics: const FixedExtentScrollPhysics(),
            controller: FixedExtentScrollController(
                initialItem: (value - min) ~/ step),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              onChanged(min + i * step);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: ((max - min) ~/ step) + 1,
              builder: (ctx, i) {
                final val = min + i * step;
                final isSelected = val == value;
                return Center(
                  child: Text(
                    val.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      fontSize: isSelected ? 22 : 16,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _proceed() {
    final isPremium =
        ref.read(hasFeatureProvider(PremiumFeature.focusModeCustomization));
    if (!isPremium) {
      showPremiumPaywall(context, triggerFeature: 'Muraqaba Focus');
      return;
    }
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) =>
            ZenModePermissionsScreen(durationMinutes: _selectedMinutes),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0.06, 0), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = ref.watch(zenModeProvider);

    if (zen.isActive && !zen.hasExpired) {
      return const ZenModeActiveScreen();
    }

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: _bg,
        body: FadeTransition(
          opacity: _fadeCtrl,
          child: Stack(
            children: [
              _buildAmbientGlow(),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(zen),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              _buildHero(),
                              const SizedBox(height: 36),
                              _buildDurationSection(),
                              const SizedBox(height: 32),
                              _buildWhatHappensSection(),
                              const SizedBox(height: 32),
                              _buildBenefitsSection(),
                              const SizedBox(height: 48),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildBottomCTA(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (_, _) => CustomPaint(
        painter: _GlowPainter(_breatheAnim.value),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildTopBar(ZenModeState zen) {
    final isPremium =
        ref.watch(hasFeatureProvider(PremiumFeature.focusModeCustomization));
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
          if (!isPremium)
            GestureDetector(
              onTap: () =>
                  showPremiumPaywall(context, triggerFeature: 'Muraqaba Focus'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFC2A366).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        color: const Color(0xFFC2A366).withValues(alpha: 0.9),
                        size: 11),
                    const SizedBox(width: 5),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color:
                            const Color(0xFFC2A366).withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (zen.sessionsCompleted > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _sage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _sage.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: _sageLight, size: 12),
                  const SizedBox(width: 5),
                  Text(
                    '${zen.sessionsCompleted} sessions',
                    style: TextStyle(
                      color: _sageLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        Center(
          child: AnimatedBuilder(
            animation: _breatheAnim,
            builder: (_, _) {
              final scale = 0.92 + (_breatheAnim.value * 0.08);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _sage.withValues(
                            alpha: 0.22 + _breatheAnim.value * 0.08),
                        _sage.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.65, 1.0],
                    ),
                    border: Border.all(
                      color: _sage.withValues(
                          alpha: 0.3 + _breatheAnim.value * 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.spa_rounded,
                      color: _sageLight.withValues(
                          alpha: 0.7 + _breatheAnim.value * 0.3),
                      size: 38,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Muraqaba',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A time of deep focus.\nBe present. Remember Allah.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DURATION',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presets.map((min) => _DurationChip(
                  label: _formatDuration(min),
                  isSelected: _selectedMinutes == min,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMinutes = min);
                  },
                  sage: _sage,
                  sageLight: _sageLight,
                  border: _border,
                )),
            GestureDetector(
              onTap: _showCustomDurationPicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: !_presets.contains(_selectedMinutes)
                        ? _sage.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.12),
                    width: !_presets.contains(_selectedMinutes) ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded,
                        color: !_presets.contains(_selectedMinutes)
                            ? _sageLight
                            : Colors.white.withValues(alpha: 0.4),
                        size: 13),
                    const SizedBox(width: 5),
                    Text(
                      !_presets.contains(_selectedMinutes)
                          ? _formatDuration(_selectedMinutes)
                          : 'Custom',
                      style: TextStyle(
                        color: !_presets.contains(_selectedMinutes)
                            ? _sageLight
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 12.5,
                        fontWeight: !_presets.contains(_selectedMinutes)
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWhatHappensSection() {
    final items = [
      _InfoItem(
        icon: Icons.apps_rounded,
        color: const Color(0xFF5C7DD4),
        title: 'All apps locked',
        desc: 'Every app is blocked. No social media, no distractions.',
      ),
      _InfoItem(
        icon: Icons.notifications_off_rounded,
        color: const Color(0xFFD4835C),
        title: 'Notifications silenced',
        desc: 'Do Not Disturb activates. Nothing interrupts your peace.',
      ),
      _InfoItem(
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFF5C8A6E),
        title: 'Camera accessible',
        desc: 'You can still open the camera for quick captures.',
      ),
      _InfoItem(
        icon: Icons.lock_clock_rounded,
        color: const Color(0xFFD4A853),
        title: 'Cannot exit early',
        desc: 'The session runs until the timer ends. Stay committed.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT HAPPENS',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        ...items.map((item) => _buildInfoCard(item)),
      ],
    );
  }

  Widget _buildInfoCard(_InfoItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.color.withValues(alpha: 0.1),
              border: Border.all(color: item.color.withValues(alpha: 0.25)),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _sage.withValues(alpha: 0.08),
            _sage.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _sage.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined,
                  color: _sageLight.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 8),
              Text(
                'Why it works',
                style: TextStyle(
                  color: _sageLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _benefitPoint('🧠',
              'Breaks phone addiction loops by forcing pattern interruption'),
          _benefitPoint('🌙',
              'In Ramadan, distraction-free time deepens your connection with Allah'),
          _benefitPoint('🔋',
              'Even 20 minutes offline recharges mental energy significantly'),
          _benefitPoint(
              '📖', 'Ideal before Quran, salah, or any focused ibadah'),
        ],
      ),
    );
  }

  Widget _benefitPoint(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          GestureDetector(
            onTap: _proceed,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _sage.withValues(alpha: 0.95),
                    _sageDim.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: _sage.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.spa_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Begin — ${_formatDuration(_selectedMinutes)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You'll be asked for permissions next",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duration chip
// ─────────────────────────────────────────────────────────────────────────────

class _DurationChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color sage;
  final Color sageLight;
  final Color border;

  const _DurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.sage,
    required this.sageLight,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? sage.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? sage.withValues(alpha: 0.45) : border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? sageLight : Colors.white.withValues(alpha: 0.35),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info item model
// ─────────────────────────────────────────────────────────────────────────────

class _InfoItem {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _InfoItem(
      {required this.icon,
      required this.color,
      required this.title,
      required this.desc});
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient glow painter
// ─────────────────────────────────────────────────────────────────────────────

class _GlowPainter extends CustomPainter {
  final double progress;
  const _GlowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = (0.04 + progress * 0.03).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.4),
        radius: 0.8,
        colors: [
          Color.fromRGBO(92, 138, 110, (alpha * 2.5).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.8))
      ..blendMode = BlendMode.screen;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.7), paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.progress != progress;
}
