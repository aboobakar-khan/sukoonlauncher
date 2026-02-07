import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/deen_mode_provider.dart';
import '../providers/premium_provider.dart';
import '../screens/deen_mode_entry_screen.dart';
import '../screens/deen_mode_screen.dart';
import '../screens/premium_paywall_screen.dart';

/// Deen Mode Widget — Minimalist Camel Design 🐪
/// Clean, subtle entry point on the dashboard
class DeenModeWidget extends ConsumerWidget {
  const DeenModeWidget({super.key});

  static const _sandGold = Color(0xFFC2A366);
  static const _camelBrown = Color(0xFFA67B5B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deenMode = ref.watch(deenModeProvider);
    final isPremium = ref.watch(premiumProvider).isPremium;
    
    // If not premium, show locked state
    if (!isPremium) {
      return _buildMinimalCard(context, false);
    }
    
    // If Deen Mode is active, show status
    if (deenMode.isEnabled && !deenMode.hasExpired) {
      return _buildActiveCard(context, deenMode);
    }
    
    // Show entry card
    return _buildMinimalCard(context, true);
  }

  Widget _buildMinimalCard(BuildContext context, bool isPremium) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (!isPremium) {
          showPremiumPaywall(context, triggerFeature: 'Deen Mode');
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeenModeEntryScreen(),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _sandGold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _sandGold.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            // Minimal crescent icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _sandGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '☪',
                  style: TextStyle(
                    fontSize: 16,
                    color: _sandGold.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Deen Mode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_sandGold, _camelBrown],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Silence distractions, nurture faith',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isPremium ? Icons.arrow_forward_ios : Icons.lock_outline,
              size: 14,
              color: _sandGold.withValues(alpha: isPremium ? 0.4 : 0.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCard(BuildContext context, dynamic deenMode) {
    final remaining = deenMode.remainingTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${minutes}m left' : '${minutes}m left';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DeenModeScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _sandGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _sandGold.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _sandGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _sandGold.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '☪',
                  style: TextStyle(fontSize: 16, color: _sandGold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _sandGold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _sandGold.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Deen Mode Active',
                        style: TextStyle(
                          color: _sandGold.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: _sandGold.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
