import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/premium_provider.dart';
import '../screens/premium_paywall_screen.dart';

/// Premium badge that shows in the app bar or settings
/// Tapping opens the paywall or premium management
class PremiumBadge extends ConsumerWidget {
  final bool showLabel;
  final double size;

  const PremiumBadge({
    super.key,
    this.showLabel = true,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumState = ref.watch(premiumProvider);

    return GestureDetector(
      onTap: () {
        if (premiumState.isPremium) {
          _showPremiumStatus(context, premiumState);
        } else {
          showPremiumPaywall(context);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 12 : 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          gradient: premiumState.isPremium
              ? const LinearGradient(
                  colors: [Color(0xFFC2A366), Color(0xFFA67B5B)],
                )
              : null,
          color: premiumState.isPremium ? null : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: premiumState.isPremium
              ? null
              : Border.all(color: const Color(0xFFC2A366).withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              premiumState.isPremium
                  ? Icons.workspace_premium
                  : Icons.lock_open,
              color: premiumState.isPremium
                  ? Colors.white
                  : const Color(0xFFC2A366),
              size: size * 0.5,
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                premiumState.isPremium ? 'PRO' : 'Upgrade',
                style: TextStyle(
                  color: premiumState.isPremium
                      ? Colors.white
                      : const Color(0xFFC2A366),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPremiumStatus(BuildContext context, PremiumState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Premium status icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC2A366), Color(0xFFA67B5B)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC2A366).withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 32,
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              'Premium Active',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Thank you for your support!',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Subscription details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Plan', state.subscriptionType?.toUpperCase() ?? 'N/A'),
                  const SizedBox(height: 12),
                  if (state.expiryDate != null)
                    _buildDetailRow(
                      'Expires',
                      '${state.expiryDate!.day}/${state.expiryDate!.month}/${state.expiryDate!.year}',
                    )
                  else
                    _buildDetailRow('Expires', 'Never (Lifetime)'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Features unlocked
            Text(
              'All features unlocked ✓',
              style: TextStyle(
                color: const Color(0xFFC2A366).withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Settings tile for premium
class PremiumSettingsTile extends ConsumerWidget {
  const PremiumSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumState = ref.watch(premiumProvider);

    return GestureDetector(
      onTap: () {
        if (premiumState.isPremium) {
          // Show bottom sheet with premium status
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => _PremiumStatusSheet(state: premiumState),
          );
        } else {
          showPremiumPaywall(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: premiumState.isPremium
              ? LinearGradient(
                  colors: [
                    const Color(0xFFC2A366).withValues(alpha: 0.15),
                    const Color(0xFFA67B5B).withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: premiumState.isPremium ? null : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: premiumState.isPremium
                ? const Color(0xFFC2A366).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: premiumState.isPremium
                    ? const LinearGradient(
                        colors: [Color(0xFFC2A366), Color(0xFFA67B5B)],
                      )
                    : null,
                color: premiumState.isPremium
                    ? null
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                premiumState.isPremium
                    ? Icons.workspace_premium
                    : Icons.stars,
                color: premiumState.isPremium
                    ? Colors.white
                    : const Color(0xFFC2A366),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    premiumState.isPremium ? 'Premium Active' : 'Upgrade to Premium',
                    style: TextStyle(
                      color: premiumState.isPremium
                          ? const Color(0xFFC2A366)
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    premiumState.isPremium
                        ? 'All features unlocked'
                        : 'Unlock all features & themes',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              premiumState.isPremium
                  ? Icons.check_circle
                  : Icons.chevron_right,
              color: premiumState.isPremium
                  ? const Color(0xFFC2A366)
                  : Colors.white.withValues(alpha: 0.3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumStatusSheet extends StatelessWidget {
  final PremiumState state;

  const _PremiumStatusSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC2A366), Color(0xFFA67B5B)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC2A366).withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 32,
            ),
          ),
          
          const SizedBox(height: 20),
          
          const Text(
            'Premium Active ✓',
            style: TextStyle(
              color: Color(0xFFC2A366),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            state.subscriptionType == 'lifetime'
                ? 'Lifetime access'
                : 'Plan: ${state.subscriptionType?.toUpperCase() ?? 'N/A'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          
          if (state.expiryDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Renews: ${state.expiryDate!.day}/${state.expiryDate!.month}/${state.expiryDate!.year}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }
}

/// Locked feature overlay - use on features that require premium
class LockedFeatureOverlay extends StatelessWidget {
  final Widget child;
  final String featureName;

  const LockedFeatureOverlay({
    super.key,
    required this.child,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blurred/dimmed child
        Opacity(
          opacity: 0.4,
          child: IgnorePointer(child: child),
        ),
        
        // Lock overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: () => showPremiumPaywall(
              context,
              triggerFeature: featureName,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC2A366).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Color(0xFFC2A366),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Premium Feature',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to unlock',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
