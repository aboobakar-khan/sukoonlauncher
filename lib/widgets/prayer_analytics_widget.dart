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

  static const Color _green = Color(0xFF40C463);

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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPremium
                ? [
                    _green.withValues(alpha: 0.1),
                    _green.withValues(alpha: 0.04),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.03),
                    Colors.white.withValues(alpha: 0.01),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPremium
                ? _green.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mosque,
                    color: isPremium ? _green : Colors.white.withValues(alpha: 0.4),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Prayer Analytics',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isPremium ? 0.9 : 0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (!isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF40C463), Color(0xFF30A14E)],
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
                    color: _green.withValues(alpha: 0.5),
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Mini stats
            Row(
              children: [
                _buildMiniStat(
                  Icons.calendar_today,
                  '$thisWeekCount/35',
                  'This Week',
                  _green,
                  isPremium,
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                  Icons.star,
                  perfectDays.toString(),
                  'Perfect Days',
                  Colors.amber,
                  isPremium,
                ),
              ],
            ),

            if (isPremium) ...[
              const SizedBox(height: 16),
              // Weekly prayer dots
              Row(
                children: List.generate(7, (i) {
                  final date = now.subtract(Duration(days: 6 - i));
                  final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  final record = recordsMap[key];
                  final completed = record?.completedCount ?? 0;

                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 6 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: completed == 0
                            ? Colors.white.withValues(alpha: 0.05)
                            : completed == 5
                                ? _green
                                : _green.withValues(alpha: completed / 5 * 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color, bool isPremium) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            color: isPremium ? color : Colors.white.withValues(alpha: 0.3),
            size: 14,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPremium ? value : '•••',
                style: TextStyle(
                  color: isPremium ? color : Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: isPremium ? 0.4 : 0.2),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
