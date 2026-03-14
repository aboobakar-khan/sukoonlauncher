import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dhikr_history_provider.dart';
import '../providers/tasbih_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/dhikr_history_pro_dashboard_redesigned.dart';

/// Dhikr Analytics Dashboard Widget - Compact card for main dashboard
class DhikrAnalyticsWidget extends ConsumerWidget {
  const DhikrAnalyticsWidget({super.key});

  static const Color _cardBg = Color(0xFF111111);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(dhikrHistoryProvider);
    final tasbih = ref.watch(tasbihProvider);
    final green = ref.watch(themeColorProvider).color;

    final realTotal = history.totalAllTime > 0 ? history.totalAllTime : tasbih.totalAllTime;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DhikrHistoryProDashboard()),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: green.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.auto_graph, color: green, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dhikr Analytics',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatNumber(realTotal)} total · ${tasbih.streakDays} day streak',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: green.withValues(alpha: 0.4), size: 14),
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
