import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_provider.dart';
import '../screens/prayer_history_dashboard_redesigned.dart';

/// Prayer Analytics Dashboard Widget - Compact card for main dashboard
class PrayerAnalyticsWidget extends ConsumerWidget {
  const PrayerAnalyticsWidget({super.key});

  static const Color _gold = Color(0xFFC2A366);
  static const Color _cardBg = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsMap = ref.watch(prayerRecordsMapProvider);

    // Calculate this week's data
    final now = DateTime.now();
    int thisWeekCount = 0;
    final weekDays = <int>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final record = recordsMap[key];
      final count = record?.completedCount ?? 0;
      thisWeekCount += count;
      weekDays.add(count);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrayerHistoryDashboard()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Prayer Analytics',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
                const Spacer(),
                Text('$thisWeekCount/35',
                  style: TextStyle(
                      color: _gold.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            // Mini week bar chart
            Row(
              children: List.generate(7, (i) {
                final count = weekDays[i];
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                    child: Column(
                      children: [
                        Container(
                          height: 3 + (count / 5 * 16),
                          decoration: BoxDecoration(
                            color: count > 0
                                ? _gold.withValues(
                                    alpha: 0.25 + (count / 5 * 0.75))
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? _gold.withValues(alpha: 0.5)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
