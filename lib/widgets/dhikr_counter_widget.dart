import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tasbih_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/dhikr_history_pro_dashboard.dart';

/// Dhikr Counter Widget - Professional Minimalist Design
/// 
/// Design Principles:
/// 1. Minimalist UI - Clean, focused interface
/// 2. Haptic Feedback - Tactile confirmation on each count
/// 3. Visual Progress - Circular progress toward target
/// 4. Smooth Animations - Micro-interactions for engagement
/// 5. Islamic Typography - Arabic dhikr with transliteration
class DhikrCounterWidget extends ConsumerStatefulWidget {
  const DhikrCounterWidget({super.key});

  @override
  ConsumerState<DhikrCounterWidget> createState() => _DhikrCounterWidgetState();
}

class _DhikrCounterWidgetState extends ConsumerState<DhikrCounterWidget>
    with TickerProviderStateMixin {
  late AnimationController _countAnimController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  // 🐪 Camel-brand design tokens
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _borderColor = Color(0xFF21262D);
  static const Color _amberPrimary = Color(0xFFC2A366);   // Camel sand gold
  static const Color _amberLight = Color(0xFFE8D5B7);     // Sand beige
  static const Color _amberDark = Color(0xFFA67B5B);      // Camel brown
  static const Color _greenPrimary = Color(0xFF7BAE6E);   // Oasis green
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _textMuted = Color(0xFF484F58);

  // Dhikr list with Arabic and virtues — authentic from Hadith
  static const List<Map<String, String>> _dhikrList = [
    {
      'arabic': 'سُبْحَانَ اللهِ',
      'transliteration': 'SubhanAllah',
      'meaning': 'Glory be to Allah',
      'virtue': 'A tree planted in Jannah',
    },
    {
      'arabic': 'الْحَمْدُ لِلَّهِ',
      'transliteration': 'Alhamdulillah',
      'meaning': 'All praise is for Allah',
      'virtue': 'Fills the scales',
    },
    {
      'arabic': 'اللهُ أَكْبَرُ',
      'transliteration': 'Allahu Akbar',
      'meaning': 'Allah is the Greatest',
      'virtue': 'Fills the heavens',
    },
    {
      'arabic': 'لَا إِلَٰهَ إِلَّا اللهُ',
      'transliteration': 'La ilaha illallah',
      'meaning': 'None worthy of worship but Allah',
      'virtue': 'Best of all dhikr',
    },
    {
      'arabic': 'أَسْتَغْفِرُ اللهَ',
      'transliteration': 'Astaghfirullah',
      'meaning': 'I seek forgiveness from Allah',
      'virtue': 'Sins forgiven like sea foam',
    },
    {
      'arabic': 'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
      'transliteration': 'SubhanAllahi wa bihamdihi',
      'meaning': 'Glory and praise be to Allah',
      'virtue': 'Beloved words to Allah — Muslim',
    },
    {
      'arabic': 'سُبْحَانَ اللهِ الْعَظِيمِ',
      'transliteration': 'SubhanAllahil Azeem',
      'meaning': 'Glory be to Allah, the Almighty',
      'virtue': 'Heavy on the scales — Bukhari',
    },
    {
      'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ',
      'transliteration': 'La hawla wa la quwwata illa billah',
      'meaning': 'No power except with Allah',
      'virtue': 'A treasure of Jannah — Bukhari',
    },
    {
      'arabic': 'حَسْبُنَا اللهُ وَنِعْمَ الْوَكِيلُ',
      'transliteration': 'HasbunAllahu wa ni\'mal wakeel',
      'meaning': 'Allah is sufficient for us',
      'virtue': 'Said by Ibrahim (AS) — Bukhari',
    },
    {
      'arabic': 'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
      'transliteration': 'Allahumma salli ala Muhammad',
      'meaning': 'O Allah, send blessings upon Muhammad ﷺ',
      'virtue': '10 blessings for each one — Muslim',
    },
    {
      'arabic': 'لَا إِلَٰهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
      'transliteration': 'La ilaha illallahu wahdahu la shareeka lah',
      'meaning': 'None worthy of worship but Allah alone',
      'virtue': '100x = freeing 10 slaves — Bukhari',
    },
    {
      'arabic': 'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ',
      'transliteration': 'Rabbighfirli wa tub alayya',
      'meaning': 'My Lord, forgive me and accept my repentance',
      'virtue': 'Prophet ﷺ said it 100x daily — Abu Dawud',
    },
  ];

  @override
  void initState() {
    super.initState();
    
    _countAnimController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _countAnimController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countAnimController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _incrementCount() {
    HapticFeedback.lightImpact();
    _countAnimController.forward().then((_) {
      _countAnimController.reverse();
    });
    ref.read(tasbihProvider.notifier).increment();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final tasbihState = ref.watch(tasbihProvider);
    final currentDhikr = _dhikrList[tasbihState.selectedDhikrIndex % _dhikrList.length];
    final progress = tasbihState.currentCount / tasbihState.targetCount;
    final isCompleted = tasbihState.currentCount >= tasbihState.targetCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted 
              ? _amberPrimary.withOpacity(0.4)
              : _borderColor,
          width: isCompleted ? 1.5 : 1,
        ),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: _amberPrimary.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header with navigation to dashboard
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const DhikrHistoryProDashboard(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Animated glow icon
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _amberPrimary.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: _amberPrimary.withOpacity(_glowAnimation.value * 0.3),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: _amberPrimary,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  
                  // Title & streak
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DHIKR COUNTER',
                              style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                                color: themeColor.color.withOpacity(0.9),
                              ),
                            ),
                            if (tasbihState.streakDays > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _amberPrimary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      color: _amberPrimary,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${tasbihState.streakDays}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _amberPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${_formatNumber(tasbihState.totalAllTime)} • Today: ${tasbihState.todayCount}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dhikr selector pills
          Container(
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dhikrList.length,
              itemBuilder: (context, index) {
                final isSelected = index == tasbihState.selectedDhikrIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(tasbihProvider.notifier).selectDhikr(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _amberPrimary.withOpacity(0.15)
                          : _bgDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected 
                            ? _amberPrimary.withOpacity(0.5)
                            : _borderColor,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dhikrList[index]['transliteration']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? _amberLight : _textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Main counter area
          GestureDetector(
            onTap: _incrementCount,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _bgDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCompleted 
                        ? _amberPrimary.withOpacity(0.3)
                        : _borderColor,
                  ),
                ),
                child: Column(
                  children: [
                    // Arabic text
                    Text(
                      currentDhikr['arabic']!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary,
                        height: 1.5,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentDhikr['meaning']!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Circular progress with count
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress ring
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: math.min(progress, 1.0)),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return CustomPaint(
                                painter: _CircularProgressPainter(
                                  progress: value,
                                  backgroundColor: _borderColor,
                                  progressColor: isCompleted 
                                      ? _greenPrimary 
                                      : _amberPrimary,
                                  strokeWidth: 6,
                                ),
                              );
                            },
                          ),
                        ),
                        // Count display
                        Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: Text(
                                '${tasbihState.currentCount}',
                                key: ValueKey(tasbihState.currentCount),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w300,
                                  color: isCompleted ? _greenPrimary : _textPrimary,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            Text(
                              '/ ${tasbihState.targetCount}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    
                    // Tap hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: _textMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted ? 'Target reached!' : 'Tap to count',
                          style: TextStyle(
                            fontSize: 11,
                            color: isCompleted ? _greenPrimary : _textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.refresh_rounded,
                    label: 'Reset',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(tasbihProvider.notifier).reset();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAction(
                    icon: Icons.settings_rounded,
                    label: 'Target: ${tasbihState.targetCount}',
                    onTap: () {
                      _showTargetPicker(context, ref, tasbihState.targetCount);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _textMuted, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTargetPicker(BuildContext context, WidgetRef ref, int currentTarget) {
    final targets = [33, 99, 100, 500, 1000];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Target Count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: targets.map((target) {
                final isSelected = target == currentTarget;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(tasbihProvider.notifier).setTarget(target);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? _amberPrimary.withOpacity(0.15)
                          : _bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? _amberPrimary
                            : _borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$target',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _amberPrimary : _textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// Circular progress painter
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
