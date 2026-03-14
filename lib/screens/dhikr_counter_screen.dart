import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tasbih_provider.dart';
import '../providers/theme_provider.dart';
import 'dhikr_history_pro_dashboard_redesigned.dart';

/// Full-screen Dhikr Counter — Immersive Islamic counting experience
/// Warm cream/gold light theme matching Sukoon design language.
class DhikrCounterScreen extends ConsumerStatefulWidget {
  const DhikrCounterScreen({super.key});

  @override
  ConsumerState<DhikrCounterScreen> createState() => _DhikrCounterScreenState();
}

class _DhikrCounterScreenState extends ConsumerState<DhikrCounterScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens - DARK MODE ──
  static const _darkBg = Color(0xFF121212);
  static const _cardBg = Color(0xFF1E1E1E);
  static const _gold = Color(0xFFC2A366);
  Color get _green => ref.watch(themeColorProvider).color;
  static const _textPrimary = Color(0xFFE8E8E8);
  static const _textSecondary = Color(0xFFB0B0B0);
  static const _textTertiary = Color(0xFF808080);
  static const _border = Color(0xFF2A2A2A);

  late AnimationController _tapCtrl;
  late Animation<double> _scaleAnim;

  // Dhikr list with Arabic and virtues — authentic from Hadith
  static const List<Map<String, String>> _dhikrList = [
    {'arabic': 'سُبْحَانَ اللهِ', 'trans': 'SubhanAllah', 'meaning': 'Glory be to Allah', 'virtue': 'A tree planted in Jannah'},
    {'arabic': 'الْحَمْدُ لِلَّهِ', 'trans': 'Alhamdulillah', 'meaning': 'All praise is for Allah', 'virtue': 'Fills the scales'},
    {'arabic': 'اللهُ أَكْبَرُ', 'trans': 'Allahu Akbar', 'meaning': 'Allah is the Greatest', 'virtue': 'Fills the heavens'},
    {'arabic': 'لَا إِلَٰهَ إِلَّا اللهُ', 'trans': 'La ilaha illallah', 'meaning': 'None worthy of worship but Allah', 'virtue': 'Best of all dhikr'},
    {'arabic': 'أَسْتَغْفِرُ اللهَ', 'trans': 'Astaghfirullah', 'meaning': 'I seek forgiveness from Allah', 'virtue': 'Sins forgiven like sea foam'},
    {'arabic': 'سُبْحَانَ اللهِ وَبِحَمْدِهِ', 'trans': 'SubhanAllahi wa bihamdihi', 'meaning': 'Glory and praise be to Allah', 'virtue': 'Beloved words to Allah'},
    {'arabic': 'سُبْحَانَ اللهِ الْعَظِيمِ', 'trans': 'SubhanAllahil Azeem', 'meaning': 'Glory be to Allah, the Almighty', 'virtue': 'Heavy on the scales'},
    {'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ', 'trans': 'La hawla wa la quwwata illa billah', 'meaning': 'No power except with Allah', 'virtue': 'A treasure of Jannah'},
    {'arabic': 'حَسْبُنَا اللهُ وَنِعْمَ الْوَكِيلُ', 'trans': 'HasbunAllahu wa ni\'mal wakeel', 'meaning': 'Allah is sufficient for us', 'virtue': 'Said by Ibrahim (AS)'},
    {'arabic': 'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ', 'trans': 'Allahumma salli ala Muhammad', 'meaning': 'O Allah, send blessings upon Muhammad ﷺ', 'virtue': '10 blessings for each one'},
    {'arabic': 'لَا إِلَٰهَ إِلَّا اللهُ وَحْدَهُ لَا شَرِيكَ لَهُ', 'trans': 'La ilaha illallahu wahdahu...', 'meaning': 'None worthy of worship but Allah alone', 'virtue': '100x = freeing 10 slaves'},
    {'arabic': 'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ', 'trans': 'Rabbighfirli wa tub alayya', 'meaning': 'My Lord, forgive me', 'virtue': 'Prophet ﷺ said it 100x daily'},
  ];

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  void _incrementCount() {
    HapticFeedback.lightImpact();
    _tapCtrl.forward().then((_) => _tapCtrl.reverse());
    ref.read(tasbihProvider.notifier).increment();
  }

  @override
  Widget build(BuildContext context) {
    final tasbih = ref.watch(tasbihProvider);
    final dhikr = _dhikrList[tasbih.selectedDhikrIndex % _dhikrList.length];
    final progress = tasbih.targetCount > 0
        ? (tasbih.currentCount / tasbih.targetCount).clamp(0.0, 1.0)
        : 0.0;
    final done = tasbih.currentCount >= tasbih.targetCount;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: _darkBg,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _darkBg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              _buildTopBar(context, tasbih),

              // ── Content ──
              Expanded(
                child: Column(
                  children: [
                    // Dhikr selector pills
                    const SizedBox(height: 12),
                    _buildDhikrPills(tasbih.selectedDhikrIndex),

                    const Spacer(flex: 2),

                    // Arabic text + meaning
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            dhikr['arabic']!,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dhikr['meaning']!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _textTertiary.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Giant counter circle — TAP AREA
                    GestureDetector(
                      onTap: _incrementCount,
                      child: ScaleTransition(
                        scale: _scaleAnim,
                        child: Container(
                          width: 164,
                          height: 164,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _cardBg,
                            border: Border.all(
                              color: done
                                  ? _green.withValues(alpha: 0.3)
                                  : _border,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (done ? _green : _gold)
                                    .withValues(alpha: 0.10),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress ring
                              SizedBox(
                                width: 140,
                                height: 140,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: progress),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  builder: (context2, val, child2) {
                                    return CustomPaint(
                                      size: const Size(140, 140),
                                      painter: _RingPainter(
                                        progress: val,
                                        bgColor: _border.withValues(alpha: 0.35),
                                        fgColor: done ? _green : _gold,
                                        stroke: 4.5,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Count display
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 120),
                                    transitionBuilder: (child, anim) =>
                                        ScaleTransition(scale: anim, child: child),
                                    child: Text(
                                      '${tasbih.currentCount}',
                                      key: ValueKey(tasbih.currentCount),
                                      style: TextStyle(
                                        color: done ? _green : _textPrimary,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1.5,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '/ ${tasbih.targetCount}',
                                    style: TextStyle(
                                      color: _textSecondary.withValues(alpha: 0.6),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Virtue text
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: (done ? _green : _gold).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dhikr['virtue']!,
                        style: TextStyle(
                          color: done
                              ? _green.withValues(alpha: 0.9)
                              : _gold.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Action bar
                    _buildActionBar(tasbih),

                    const Spacer(flex: 1),

                    // Stats row
                    _buildStatsRow(tasbih),

                    const SizedBox(height: 16),

                    // Bottom hint
                    Text(
                      'Tap the circle to count  ·  Scroll pills to change dhikr',
                      style: TextStyle(
                        color: _textTertiary.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────
  // TOP BAR
  // ────────────────────────
  Widget _buildTopBar(BuildContext context, TasbihState tasbih) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          // Title + streak
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dhikr Counter',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if (tasbih.streakDays > 0)
                Text(
                  '🔥 ${tasbih.streakDays} day streak',
                  style: TextStyle(
                    color: _gold.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const Spacer(),
          // History / Dashboard
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (c1, a1, a2) => const DhikrHistoryProDashboard(),
                  transitionsBuilder: (c2, anim, a3, child) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 280),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded, color: _gold, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    'Analytics',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────
  // DHIKR PILLS (horizontal scroll)
  // ────────────────────────
  Widget _buildDhikrPills(int selectedIndex) {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _dhikrList.length,
        itemBuilder: (context, i) {
          final sel = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(tasbihProvider.notifier).selectDhikr(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: sel ? _gold.withValues(alpha: 0.2) : _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? _gold.withValues(alpha: 0.5) : _border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _dhikrList[i]['trans']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? _gold : _textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ────────────────────────
  // ACTION BAR (reset, target)
  // ────────────────────────
  Widget _buildActionBar(TasbihState tasbih) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionBtn(Icons.refresh_rounded, 'Reset', () {
          HapticFeedback.mediumImpact();
          ref.read(tasbihProvider.notifier).reset();
        }),
        const SizedBox(width: 12),
        Container(width: 1, height: 24, color: _border),
        const SizedBox(width: 12),
        _buildActionBtn(Icons.flag_rounded, '${tasbih.targetCount}', () {
          _showTargetPicker(context, tasbih.targetCount);
        }),
        const SizedBox(width: 12),
        Container(width: 1, height: 24, color: _border),
        const SizedBox(width: 12),
        _buildActionBtn(Icons.skip_next_rounded, 'Next', () {
          HapticFeedback.selectionClick();
          final next = (tasbih.selectedDhikrIndex + 1) % _dhikrList.length;
          ref.read(tasbihProvider.notifier).selectDhikr(next);
        }),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _textSecondary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────
  // STATS ROW
  // ────────────────────────
  Widget _buildStatsRow(TasbihState tasbih) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Today', '${tasbih.todayCount}', _gold),
            Container(width: 1, height: 28, color: _border),
            _buildStatItem('Total', _fmtNum(tasbih.totalAllTime), _green),
            Container(width: 1, height: 28, color: _border),
            _buildStatItem('Targets', '${tasbih.completedTargets}', _textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: _textTertiary.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ────────────────────────
  // TARGET PICKER
  // ────────────────────────
  void _showTargetPicker(BuildContext context, int currentTarget) {
    final targets = [33, 99, 100, 500, 1000];
    showModalBottomSheet(
      context: context,
      backgroundColor: _darkBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Set Target',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textPrimary)),
            const SizedBox(height: 4),
            Text('How many times per round?',
              style: TextStyle(fontSize: 12, color: _textSecondary.withValues(alpha: 0.8))),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: targets.map((t) {
                final sel = t == currentTarget;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(tasbihProvider.notifier).setTarget(t);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: sel ? _gold.withValues(alpha: 0.2) : _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? _gold : _border,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text('$t',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: sel ? _gold : _textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Ring painter ──
class _RingPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final double stroke;

  _RingPainter({required this.progress, required this.bgColor, required this.fgColor, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(center, radius, Paint()
      ..color = bgColor..style = PaintingStyle.stroke..strokeWidth = stroke);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = fgColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.fgColor != fgColor;
}
