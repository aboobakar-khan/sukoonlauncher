import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/clock_style_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/sukoon_coin_provider.dart';
import 'premium_paywall_screen.dart';

/// Clock Style Picker Screen
class ClockStylePickerScreen extends ConsumerWidget {
  const ClockStylePickerScreen({super.key});

  // First 3 clock styles are free (digital, analog, minimalist)
  static const int freeClockCount = 3;

  // Map clock styles to store item IDs
  static const _clockStoreMap = {
    'Analog': 'clock_analog',
    'Bold': 'clock_bold',
    'Modern': 'clock_modern',
    'Retro': 'clock_retro',
    'Elegant': 'clock_elegant',
    'Binary': 'clock_binary',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStyle = ref.watch(clockStyleProvider);
    final isPremium = ref.watch(premiumProvider).isPremium;
    final coinState = ref.watch(sukoonCoinProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Clock style list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: ClockStyle.values.length,
                itemBuilder: (context, index) {
                  final style = ClockStyle.values[index];
                  final isSelected = style == currentStyle;
                  final storeId = _clockStoreMap[style.name];
                  final purchasedViaCoin = storeId != null && coinState.ownsItem(storeId);
                  final isLocked = !isPremium && !purchasedViaCoin && index >= freeClockCount;

                  return _buildClockStyleOption(
                    context,
                    ref,
                    style,
                    isSelected,
                    isLocked,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'CLOCK STYLE',
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 4,
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockStyleOption(
    BuildContext context,
    WidgetRef ref,
    ClockStyle style,
    bool isSelected,
    bool isLocked,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isLocked) {
          showPremiumPaywall(context, triggerFeature: 'Clock: ${style.name}');
          return;
        }
        ref.read(clockStyleProvider.notifier).setClockStyle(style);
        Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Icon(
              _getIconForStyle(style),
              color: Colors.white.withValues(alpha: 0.6),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Style name
                  Text(
                    style.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 18,
                      letterSpacing: 0.5,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    style.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.white.withValues(alpha: 0.7),
                size: 24,
              )
            else if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, color: const Color(0xFFC2A366).withValues(alpha: 0.7), size: 12),
                    const SizedBox(width: 3),
                    Text('PRO', style: TextStyle(color: const Color(0xFFC2A366).withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForStyle(ClockStyle style) {
    switch (style) {
      case ClockStyle.digital:
        return Icons.schedule;
      case ClockStyle.analog:
        return Icons.access_time;
      case ClockStyle.minimalist:
        return Icons.timelapse;
      case ClockStyle.bold:
        return Icons.timer;
      case ClockStyle.compact:
        return Icons.schedule_outlined;
      case ClockStyle.modern:
        return Icons.watch_later_outlined;
      case ClockStyle.retro:
        return Icons.flip;
      case ClockStyle.elegant:
        return Icons.access_time_filled;
      case ClockStyle.binary:
        return Icons.code;
    }
  }
}
