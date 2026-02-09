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

  static const Color _green = Color(0xFF7BAE6E);  // Oasis green — app theme
  static const Color _cardBg = Color(0xFF111111);
  static const Color _borderColor = Color(0xFF1E1E1E);

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPremium
                ? _green.withValues(alpha: 0.12)
                : _borderColor,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_graph,
                color: isPremium ? _green : Colors.white.withValues(alpha: 0.3),
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
                    'Dhikr Analytics',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: isPremium ? 0.85 : 0.45),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPremium
                        ? '${_formatNumber(realTotal)} total · ${tasbih.streakDays} day streak'
                        : 'Unlock detailed dhikr insights',
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
                    colors: [Color(0xFF7BAE6E), Color(0xFF5A9B4E)],
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
                color: _green.withValues(alpha: 0.4),
                size: 14,
              ),
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
