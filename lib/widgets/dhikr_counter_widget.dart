import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tasbih_provider.dart';
import '../providers/theme_provider.dart';

import '../screens/dhikr_history_pro_dashboard_redesigned.dart';

/// Dhikr Counter Widget — Clean Minimalist Redesign
/// 
/// Principles:
/// 1. Ultra-minimal — no visual noise, pure focus
/// 2. Theme-consistent — matches app dark tokens (0xFF0A0A0A, 0xFF111111)
/// 3. Tap anywhere on counter → increment
/// 4. Smooth progress arc + haptic feedback
/// 5. Compact: header + dhikr pills + counter circle + actions
class DhikrCounterWidget extends ConsumerStatefulWidget {
  const DhikrCounterWidget({super.key});

  @override
  ConsumerState<DhikrCounterWidget> createState() => _DhikrCounterWidgetState();
}

class _DhikrCounterWidgetState extends ConsumerState<DhikrCounterWidget>
    with TickerProviderStateMixin {
  late AnimationController _countAnimController;
  late Animation<double> _scaleAnimation;

  // ☪️ Sukoon brand design tokens — consistent with app theme
  static const Color _cardBg = Color(0xFF111111);
  static const Color _surfaceBg = Color(0xFF0A0A0A);
  static const Color _borderColor = Color(0xFF1E1E1E);
  static const Color _gold = Color(0xFFC2A366);       // Sand gold
  static const Color _goldLight = Color(0xFFE8D5B7);   // Sand beige
  static const Color _green = Color(0xFF7BAE6E);       // Oasis green
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
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _countAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _countAnimController.dispose();
    super.dispose();
  }

  void _incrementCount() {
    HapticFeedback.lightImpact();
    _countAnimController.forward().then((_) => _countAnimController.reverse());
    ref.read(tasbihProvider.notifier).increment();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final tasbih = ref.watch(tasbihProvider);
    final dhikr = _dhikrList[tasbih.selectedDhikrIndex % _dhikrList.length];
    final progress = tasbih.currentCount / tasbih.targetCount;
    final done = tasbih.currentCount >= tasbih.targetCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header — tap to open dashboard ──
        _buildHeader(themeColor.color, tasbih),

        const SizedBox(height: 8),

        // ── Dhikr selector — horizontal pills ──
        _buildDhikrSelector(tasbih.selectedDhikrIndex),

        const SizedBox(height: 16),

        // ── Main counter — tap area ──
        _buildCounter(dhikr, tasbih, progress, done),

        const SizedBox(height: 10),

        // ── Quick actions ──
        _buildActions(tasbih),
      ],
    );
  }

  Widget _buildHeader(Color accent, dynamic tasbih) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DhikrHistoryProDashboard(),
            transitionsBuilder: (_, anim, __, child) {
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
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Text(
              'DHIKR',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w600,
                color: accent.withOpacity(0.7),
              ),
            ),
            if (tasbih.streakDays > 0) ...[
              const SizedBox(width: 8),
              Text('🔥 ${tasbih.streakDays}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _gold.withOpacity(0.7))),
            ],
            const Spacer(),
            Text('${_formatNumber(tasbih.totalAllTime)}',
              style: const TextStyle(fontSize: 11, color: _textMuted)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: _textMuted.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDhikrSelector(int selectedIndex) {
    return SizedBox(
      height: 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _dhikrList.length,
        itemBuilder: (context, i) {
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(tasbihProvider.notifier).selectDhikr(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected ? _gold.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? _gold.withOpacity(0.4) : _borderColor,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _dhikrList[i]['transliteration']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? _goldLight : _textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCounter(Map<String, String> dhikr, dynamic tasbih, double progress, bool done) {
    return GestureDetector(
      onTap: _incrementCount,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            // Arabic text
            Text(
              dhikr['arabic']!,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w400,
                color: _textPrimary,
                height: 1.6,
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              dhikr['meaning']!,
              style: const TextStyle(fontSize: 11, color: _textSecondary, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Progress ring + count
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: math.min(progress, 1.0)),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) {
                      return CustomPaint(
                        size: const Size(80, 80),
                        painter: _ArcPainter(
                          progress: val,
                          bgColor: _borderColor,
                          fgColor: done ? _green : _gold,
                          stroke: 4,
                        ),
                      );
                    },
                  ),
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
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                            color: done ? _green : _textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text('/ ${tasbih.targetCount}',
                        style: const TextStyle(fontSize: 10, color: _textMuted)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            Text(
              dhikr['virtue']!,
              style: TextStyle(
                fontSize: 9,
                color: done ? _green.withOpacity(0.7) : _textMuted.withOpacity(0.7),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(dynamic tasbih) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(tasbihProvider.notifier).reset();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: _textMuted.withOpacity(0.6), size: 13),
                  const SizedBox(width: 4),
                  Text('Reset',
                    style: TextStyle(fontSize: 11, color: _textMuted.withOpacity(0.6), fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
          Container(
            width: 1, height: 12,
            color: _borderColor,
          ),
          GestureDetector(
            onTap: () => _showTargetPicker(context, ref, tasbih.targetCount),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, color: _textMuted.withOpacity(0.6), size: 13),
                  const SizedBox(width: 4),
                  Text('${tasbih.targetCount}',
                    style: TextStyle(fontSize: 11, color: _textMuted.withOpacity(0.6), fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ),
        ],
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set Target',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
            const SizedBox(height: 16),
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _gold.withOpacity(0.12) : _surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? _gold : _borderColor,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text('$t',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: sel ? _gold : _textSecondary)),
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

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

/// Minimal arc painter
class _ArcPainter extends CustomPainter {
  final double progress;
  final Color bgColor;
  final Color fgColor;
  final double stroke;

  _ArcPainter({
    required this.progress,
    required this.bgColor,
    required this.fgColor,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

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

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.progress != progress || old.fgColor != fgColor;
}
