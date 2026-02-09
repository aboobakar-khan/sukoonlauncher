import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_provider.dart';
import '../providers/premium_provider.dart';
import '../screens/prayer_history_dashboard_redesigned.dart';
import '../screens/premium_paywall_screen.dart';

/// Prayer Analytics Dashboard Widget - Compact card for main dashboard
class PrayerAnalyticsWidget extends ConsumerWidget {
  const PrayerAnalyticsWidget({super.key});

  static const Color _green = Color(0xFF7BAE6E);
  static const Color _gold = Color(0xFFC2A366);
  static const Color _cardBg = Color(0xFF111111);
  static const Color _borderColor = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(premiumProvider).isPremium;
    final recordsMap = ref.watch(prayerRecordsMapProvider);

    // Calculate this week's progress
    final now = DateTime.now();
    int thisWeekCount = 0;
    int perfectDays = 0;

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final record = recordsMap[key];
      if (record != null) {
        thisWeekCount += record.completedCount;
        if (record.completedCount == 5) perfectDays++;
      }
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (!isPremium) {
          showPremiumPaywall(context, triggerFeature: 'Prayer Analytics');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrayerHistoryDashboard()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPremium
                ? _gold.withValues(alpha: 0.12)
                : _borderColor,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.mosque,
                color: isPremium ? _gold : Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prayer Analytics',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isPremium ? 0.85 : 0.45),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? '$thisWeekCount/35 this week · $perfectDays perfect days'
                        : 'Unlock detailed prayer insights',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Badge or arrow
            if (!isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC2A366), Color(0xFFA8874D)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                color: _gold.withValues(alpha: 0.4),
                size: 14,
              ),
          ],
        ),
      ),
    );
  }
}
