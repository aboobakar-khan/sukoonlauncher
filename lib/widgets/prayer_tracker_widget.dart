import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/prayer_history_dashboard.dart';

/// Prayer Tracker Widget - Professional Minimalist Design
/// 
/// Design Principles:
/// 1. Minimalist UI - Clean, uncluttered interface
/// 2. Micro-interactions - Subtle animations for engagement
/// 3. Visual Progress - Clear completion status at a glance
/// 4. Contextual Feedback - Islamic context with each prayer
/// 5. Touch Targets - 44x44px minimum for accessibility
class PrayerTrackerWidget extends ConsumerStatefulWidget {
  const PrayerTrackerWidget({super.key});

  @override
  ConsumerState<PrayerTrackerWidget> createState() => _PrayerTrackerWidgetState();
}

class _PrayerTrackerWidgetState extends ConsumerState<PrayerTrackerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Track which day we're viewing: 0 = today, 1 = yesterday
  int _selectedDayOffset = 0;

  // 🐪 Camel-brand design tokens
  static const Color _bgDark = Color(0xFF0D1117);
  static const Color _cardBg = Color(0xFF161B22);
  static const Color _borderColor = Color(0xFF21262D);
  static const Color _greenPrimary = Color(0xFF7BAE6E);   // Oasis green
  static const Color _greenLight = Color(0xFFA8D5A0);     // Soft oasis
  static const Color _greenDark = Color(0xFF5A8F50);      // Deep oasis
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _textMuted = Color(0xFF484F58);
  static const Color _amberAccent = Color(0xFFC2A366);    // Camel sand gold

  // Prayer data with Islamic context
  static const List<Map<String, dynamic>> _prayers = [
    {
      'name': 'Fajr',
      'arabicName': 'الفجر',
      'icon': Icons.wb_twilight_rounded,
      'time': 'Dawn',
      'virtue': 'Better than the world',
    },
    {
      'name': 'Dhuhr',
      'arabicName': 'الظهر',
      'icon': Icons.wb_sunny_rounded,
      'time': 'Noon',
      'virtue': 'Midday reward',
    },
    {
      'name': 'Asr',
      'arabicName': 'العصر',
      'icon': Icons.wb_sunny_outlined,
      'time': 'Afternoon',
      'virtue': 'Protected from Fire',
    },
    {
      'name': 'Maghrib',
      'arabicName': 'المغرب',
      'icon': Icons.nights_stay_outlined,
      'time': 'Sunset',
      'virtue': 'Breaking fast reward',
    },
    {
      'name': 'Isha',
      'arabicName': 'العشاء',
      'icon': Icons.dark_mode_rounded,
      'time': 'Night',
      'virtue': 'Half night prayer',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  DateTime _getSelectedDate() {
    return DateTime.now().subtract(Duration(days: _selectedDayOffset));
  }

  String _getDateKey(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';
  }

  dynamic _getRecordForSelectedDay() {
    final allRecords = ref.watch(prayerRecordListProvider);
    final dateKey = _getDateKey(_getSelectedDate());
    
    try {
      return allRecords.firstWhere((r) => r.dateKey == dateKey);
    } catch (e) {
      return null;
    }
  }

  String _getDayLabel() {
    if (_selectedDayOffset == 0) return 'Today';
    if (_selectedDayOffset == 1) return 'Yesterday';
    return '${_selectedDayOffset} days ago';
  }

  bool _isEditable() {
    // Only today and yesterday are editable
    return _selectedDayOffset <= 1;
  }

  int _getCompletedCount(dynamic todayRecord) {
    if (todayRecord == null) return 0;
    int count = 0;
    if (todayRecord.fajr) count++;
    if (todayRecord.dhuhr) count++;
    if (todayRecord.asr) count++;
    if (todayRecord.maghrib) count++;
    if (todayRecord.isha) count++;
    return count;
  }

  bool _isPrayerCompleted(dynamic todayRecord, String prayerName) {
    if (todayRecord == null) return false;
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return todayRecord.fajr;
      case 'dhuhr':
        return todayRecord.dhuhr;
      case 'asr':
        return todayRecord.asr;
      case 'maghrib':
        return todayRecord.maghrib;
      case 'isha':
        return todayRecord.isha;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final selectedRecord = _getRecordForSelectedDay();
    final completedCount = _getCompletedCount(selectedRecord);
    final progress = completedCount / 5;
    final isEditable = _isEditable();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PrayerHistoryDashboard(),
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completedCount == 5 
                ? _greenPrimary.withOpacity(0.4) 
                : _borderColor,
            width: completedCount == 5 ? 1.5 : 1,
          ),
          boxShadow: completedCount == 5
              ? [
                  BoxShadow(
                    color: _greenPrimary.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Header with day selector
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Progress ring
                      _buildProgressRing(progress, completedCount),
                      const SizedBox(width: 16),
                      
                      // Title & stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'SALAH TRACKER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: themeColor.color.withOpacity(0.9),
                                  ),
                                ),
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
                              completedCount == 5 
                                  ? 'All prayers completed! ✨'
                                  : '${5 - completedCount} ${(5 - completedCount) == 1 ? 'prayer' : 'prayers'} remaining',
                              style: TextStyle(
                                fontSize: 14,
                                color: completedCount == 5 
                                    ? _greenLight 
                                    : _textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Day selector
                  const SizedBox(height: 12),
                  _buildDaySelector(),
                ],
              ),
            ),

            // Prayer pills
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _prayers.map((prayer) {
                  final isCompleted = _isPrayerCompleted(selectedRecord, prayer['name']);
                  return _buildPrayerPill(
                    prayer: prayer,
                    isCompleted: isCompleted,
                    themeColor: themeColor.color,
                    isEditable: isEditable,
                  );
                }).toList(),
              ),
            ),

            // Progress bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: _borderColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _greenDark,
                            _greenPrimary,
                            _greenLight.withOpacity(0.5 + _pulseAnimation.value * 0.5),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDayTab('Today', 0),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildDayTab('Yesterday', 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTab(String label, int dayOffset) {
    final isSelected = _selectedDayOffset == dayOffset;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedDayOffset = dayOffset;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _greenPrimary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _greenPrimary.withOpacity(0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected && dayOffset == 0)
              Icon(
                Icons.today_rounded,
                color: _greenPrimary,
                size: 14,
              ),
            if (isSelected && dayOffset == 1)
              Icon(
                Icons.history_rounded,
                color: _amberAccent,
                size: 14,
              ),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected 
                    ? (dayOffset == 0 ? _greenPrimary : _amberAccent)
                    : _textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(double progress, int completed) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: const Size(52, 52),
            painter: _RingPainter(
              progress: 1.0,
              color: _borderColor,
              strokeWidth: 4,
            ),
          ),
          // Progress ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: const Size(52, 52),
                painter: _RingPainter(
                  progress: value,
                  color: _greenPrimary,
                  strokeWidth: 4,
                ),
              );
            },
          ),
          // Center icon/count
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: completed == 5
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('check'),
                    color: _greenPrimary,
                    size: 24,
                  )
                : Text(
                    '$completed',
                    key: ValueKey(completed),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerPill({
    required Map<String, dynamic> prayer,
    required bool isCompleted,
    required Color themeColor,
    required bool isEditable,
  }) {
    final Color pillColor;
    final Color iconColor;
    final Color textColor;
    final double opacity;
    
    if (isCompleted) {
      pillColor = _greenPrimary;
      iconColor = _greenPrimary;
      textColor = _greenLight;
      opacity = 1.0;
    } else if (!isEditable) {
      // Non-editable past prayers
      pillColor = _borderColor;
      iconColor = _textMuted.withOpacity(0.4);
      textColor = _textMuted.withOpacity(0.5);
      opacity = 0.5;
    } else {
      pillColor = _borderColor;
      iconColor = _textMuted;
      textColor = _textSecondary;
      opacity = 1.0;
    }

    return GestureDetector(
      onTap: isEditable
          ? () {
              HapticFeedback.selectionClick();
              final selectedDate = _getSelectedDate();
              ref.read(prayerRecordListProvider.notifier).togglePrayer(
                selectedDate,
                prayer['name'],
              );
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isCompleted 
                ? pillColor.withOpacity(0.15)
                : _bgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted 
                  ? pillColor.withOpacity(0.5)
                  : pillColor,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : prayer['icon'],
                  key: ValueKey('${prayer['name']}_$isCompleted'),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prayer['name'],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom ring painter for progress indicator
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
