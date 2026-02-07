import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/prayer_provider.dart';
import '../providers/tasbih_provider.dart';

/// Subtle Islamic Reminder Widget
/// 
/// Shows below the home clock - minimal, inspiring, and relevant
/// Design: Ultra-minimalist, does not distract from clock
class SubtleIslamicReminder extends ConsumerStatefulWidget {
  final Color themeColor;
  final double opacityMultiplier;
  
  const SubtleIslamicReminder({
    super.key,
    required this.themeColor,
    this.opacityMultiplier = 1.0,
  });

  @override
  ConsumerState<SubtleIslamicReminder> createState() => _SubtleIslamicReminderState();
}

class _SubtleIslamicReminderState extends ConsumerState<SubtleIslamicReminder> {
  int _currentReminderIndex = 0;
  Timer? _rotationTimer;
  
  // Context-aware reminders - rotate every 30 seconds
  static const List<Map<String, String>> _reminders = [
    {'arabic': 'بِسْمِ اللَّهِ', 'text': 'Begin with Bismillah', 'type': 'general'},
    {'arabic': 'الْحَمْدُ لِلَّهِ', 'text': 'Say Alhamdulillah', 'type': 'gratitude'},
    {'arabic': 'سُبْحَانَ اللَّهِ', 'text': 'Remember SubhanAllah', 'type': 'dhikr'},
    {'arabic': 'أَسْتَغْفِرُ اللَّهَ', 'text': 'Seek Istighfar', 'type': 'forgiveness'},
    {'arabic': 'لَا إِلَٰهَ إِلَّا اللَّهُ', 'text': 'La ilaha illallah', 'type': 'tawhid'},
    {'arabic': 'اللَّهُ أَكْبَرُ', 'text': 'Allah is Greatest', 'type': 'takbir'},
    {'arabic': 'رَبَّنَا آتِنَا', 'text': 'Make Dua for goodness', 'type': 'dua'},
    {'arabic': 'صَلِّ عَلَى النَّبِي', 'text': 'Send salawat upon the Prophet ﷺ', 'type': 'salawat'},
  ];

  @override
  void initState() {
    super.initState();
    _setInitialReminder();
    _startRotation();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _setInitialReminder() {
    // Start with a reminder based on time of day
    final hour = DateTime.now().hour;
    if (hour < 6) {
      _currentReminderIndex = 3; // Istighfar (late night)
    } else if (hour < 12) {
      _currentReminderIndex = 0; // Bismillah (morning)
    } else if (hour < 15) {
      _currentReminderIndex = 1; // Alhamdulillah (afternoon)
    } else if (hour < 18) {
      _currentReminderIndex = 2; // SubhanAllah (asr time)
    } else {
      _currentReminderIndex = 6; // Dua (evening)
    }
  }

  void _startRotation() {
    _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _currentReminderIndex = (_currentReminderIndex + 1) % _reminders.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminders[_currentReminderIndex];
    final prayerRecord = ref.watch(todayPrayerRecordProvider);
    final tasbihState = ref.watch(tasbihProvider);
    
    // Dynamic stats to show
    final prayerCount = prayerRecord?.completedCount ?? 0;
    final dhikrCount = tasbihState.currentCount;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Column(
        key: ValueKey(_currentReminderIndex),
        children: [
          // Arabic text (subtle)
          Text(
            reminder['arabic']!,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 18,
              color: widget.themeColor.withOpacity(0.35 * widget.opacityMultiplier),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          
          // English reminder
          Text(
            reminder['text']!,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1,
              color: widget.themeColor.withOpacity(0.25 * widget.opacityMultiplier),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Mini progress indicators (ultra subtle)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMiniIndicator('🕌', '$prayerCount/5'),
              const SizedBox(width: 20),
              _buildMiniIndicator('📿', '$dhikrCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniIndicator(String emoji, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: widget.themeColor.withOpacity(0.2 * widget.opacityMultiplier),
          ),
        ),
      ],
    );
  }
}

/// Minimal Islamic Status Bar
/// Shows prayer and dhikr progress in the most minimal way possible
class MinimalIslamicStatus extends ConsumerWidget {
  final Color themeColor;
  final double opacity;

  const MinimalIslamicStatus({
    super.key,
    required this.themeColor,
    this.opacity = 0.3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prayerRecord = ref.watch(todayPrayerRecordProvider);
    final prayers = [
      prayerRecord?.fajr ?? false,
      prayerRecord?.dhuhr ?? false,
      prayerRecord?.asr ?? false,
      prayerRecord?.maghrib ?? false,
      prayerRecord?.isha ?? false,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 5 prayer dots
        ...List.generate(5, (i) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: prayers[i] 
                ? const Color(0xFFC2A366).withOpacity(opacity)
                : themeColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        )),
      ],
    );
  }
}
