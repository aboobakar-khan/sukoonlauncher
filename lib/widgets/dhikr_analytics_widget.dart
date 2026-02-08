import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dhikr_history_provider.dart';
import '../providers/tasbih_provider.dart';
import '../providers/premium_provider.dart';
import '../screens/dhikr_history_pro_dashboard_redesigned.dart';
import '../screens/premium_paywall_screen.dart';

/// Dhikr Analytics Dashboard Widget - Compact card for main dashboard
class DhikrAnalyticsWidget extends ConsumerWidget {
  const DhikrAnalyticsWidget({super.key});

  static const Color _green = Color(0xFF40C463);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(premiumProvider).isPremium;
    final history = ref.watch(dhikrHistoryProvider);
    final tasbih = ref.watch(tasbihProvider);

    // Use the actual total from tasbih counter if dhikr history is empty
    final realTotal = history.totalAllTime > 0 ? history.totalAllTime : tasbih.totalAllTime;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (!isPremium) {
          showPremiumPaywall(context, triggerFeature: 'Dhikr Analytics PRO');
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DhikrHistoryProDashboard()),
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
                    Icons.auto_graph,
                    color: isPremium ? _green : Colors.white.withValues(alpha: 0.4),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Dhikr Analytics',
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
                  Icons.repeat,
                  _formatNumber(realTotal),
                  'Total',
                  _green,
                  isPremium,
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                  Icons.local_fire_department,
                  '${tasbih.streakDays}',
                  'Streak',
                  Colors.orange,
                  isPremium,
                ),
                const SizedBox(width: 16),
                _buildMiniStat(
                  Icons.emoji_events,
                  '${history.longestStreak}',
                  'Best',
                  Colors.amber,
                  isPremium,
                ),
              ],
            ),

            if (isPremium) ...[
              const SizedBox(height: 16),
              // Mini activity bar
              Row(
                children: List.generate(7, (i) {
                  final summaries = history.getDailySummaries(7);
                  final intensity = summaries[i].intensity;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 6 ? 3 : 0),
                      decoration: BoxDecoration(
                        color: intensity == 0
                            ? Colors.white.withValues(alpha: 0.05)
                            : _green.withValues(alpha: 0.2 + (intensity * 0.2)),
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

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
