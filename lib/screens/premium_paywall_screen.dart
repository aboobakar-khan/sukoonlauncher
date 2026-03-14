import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/premium_provider.dart';
import 'donation_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Premium Paywall Screen — Replaced with Donation Redirect
/// ═══════════════════════════════════════════════════════════════════════
/// 
/// All features are now free. This file is kept only for
/// backward-compatibility with existing import/navigation references.
/// It immediately redirects to the DonationScreen.
/// ═══════════════════════════════════════════════════════════════════════

class PremiumPaywallScreen extends ConsumerWidget {
  final String? triggerFeature;
  final String? milestone;

  const PremiumPaywallScreen({
    super.key,
    this.triggerFeature,
    this.milestone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Immediately navigate to donation screen and pop this placeholder
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DonationScreen()),
        );
      }
    });

    return const Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.shrink(),
    );
  }
}

/// Legacy helper function — now shows donation screen instead
Future<void> showPremiumPaywall(
  BuildContext context, {
  String? triggerFeature,
  String? milestone,
}) async {
  showDonationScreen(context);
}

/// Legacy feature gate widget — now always allows access (no gate)
class PremiumFeatureGate extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;

  const PremiumFeatureGate({
    super.key,
    required this.feature,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return child; // All features unlocked — show child directly
  }
}
