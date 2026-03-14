import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Premium Provider — ALL FEATURES FREE (Donation Model)
/// ═══════════════════════════════════════════════════════════════════════
/// 
/// As of v1.0.7, Sukoon Launcher is 100% free.
/// All features are unlocked for every user.
/// Monetization is through voluntary Razorpay donations.
/// 
/// This provider is kept for backward-compatibility —
/// every `ref.watch(premiumProvider).isPremium` call returns true,
/// so no UI code needs to change.
/// ═══════════════════════════════════════════════════════════════════════

/// Premium Features — kept for compatibility, all always unlocked
enum PremiumFeature {
  allThemeColors,
  customClockStyles,
  widgetCustomization,
  unlimitedDhikrPresets,
  advancedStatistics,
  detailedHistory,
  deenMode,
  focusModeCustomization,
  unlimitedAppBlocking,
  prayerAlarm,
  fullDuaLibrary,
  multipleTafseer,
  hadithBookmarks,
  cloudBackup,
  exportData,
  removeAds,
  prioritySupport,
}

/// Premium State — always premium
class PremiumState {
  final bool isPremium;
  final bool isStoreAvailable;
  final bool isPurchasing;
  final bool isPurchasePending;
  final String? purchaseError;
  final String? subscriptionType;
  final DateTime? lastStatusCheck;
  final int paywallDismissCount;
  final DateTime? lastPaywallShown;
  final int consecutiveDaysUsed;
  final int totalDhikrCount;
  final int totalPrayersTracked;

  const PremiumState({
    this.isPremium = true, // Always true — everything is free now
    this.isStoreAvailable = false,
    this.isPurchasing = false,
    this.isPurchasePending = false,
    this.purchaseError,
    this.subscriptionType,
    this.lastStatusCheck,
    this.paywallDismissCount = 0,
    this.lastPaywallShown,
    this.consecutiveDaysUsed = 0,
    this.totalDhikrCount = 0,
    this.totalPrayersTracked = 0,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isStoreAvailable,
    bool? isPurchasing,
    bool? isPurchasePending,
    String? purchaseError,
    String? subscriptionType,
    DateTime? lastStatusCheck,
    int? paywallDismissCount,
    DateTime? lastPaywallShown,
    int? consecutiveDaysUsed,
    int? totalDhikrCount,
    int? totalPrayersTracked,
  }) {
    return PremiumState(
      isPremium: true, // Always true
      isStoreAvailable: isStoreAvailable ?? this.isStoreAvailable,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isPurchasePending: isPurchasePending ?? this.isPurchasePending,
      purchaseError: purchaseError,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      lastStatusCheck: lastStatusCheck ?? this.lastStatusCheck,
      paywallDismissCount: paywallDismissCount ?? this.paywallDismissCount,
      lastPaywallShown: lastPaywallShown ?? this.lastPaywallShown,
      consecutiveDaysUsed: consecutiveDaysUsed ?? this.consecutiveDaysUsed,
      totalDhikrCount: totalDhikrCount ?? this.totalDhikrCount,
      totalPrayersTracked: totalPrayersTracked ?? this.totalPrayersTracked,
    );
  }

  bool get needsRenewalWarning => false;
  bool get isReadyForUpsell => false;
}

/// Premium Notifier — Lightweight (no billing integration needed)
class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState());

  /// No-op — everything is free
  Future<void> checkSubscriptionStatus() async {
    debugPrint('PremiumNotifier: ✅ All features free — no subscription check needed');
  }

  /// No-op stubs for backward compatibility
  Future<bool> purchase(String productId) async => true;
  Future<bool> restorePurchases() async => true;
  bool hasFeature(PremiumFeature feature) => true;

  Future<void> trackPaywallDismiss() async {}
  Future<void> trackPaywallView() async {}
  Future<void> updateEngagement({int? dhikrAdded, int? prayersAdded, bool? dailyUsage}) async {}
}

/// Providers
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
  (ref) => PremiumNotifier(),
);

/// Helper provider for quick premium check — always true
final isPremiumProvider = Provider<bool>((ref) {
  return true; // Everything is free
});

/// Helper provider for feature access — always true
final hasFeatureProvider = Provider.family<bool, PremiumFeature>((ref, feature) {
  return true; // All features unlocked
});
