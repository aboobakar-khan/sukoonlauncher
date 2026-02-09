import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'camel_coin_provider.dart';

/// Premium Features - What's included in premium
enum PremiumFeature {
  // Theme & Customization
  allThemeColors,
  customClockStyles,
  widgetCustomization,
  
  // Dhikr & Prayer
  unlimitedDhikrPresets,
  advancedStatistics,
  detailedHistory,
  
  // Focus & Productivity
  deenMode,
  focusModeCustomization,
  unlimitedAppBlocking,
  
  // Content
  fullDuaLibrary,
  multipleTafseer,
  hadithBookmarks,
  
  // Data
  cloudBackup,
  exportData,
  
  // Experience
  removeAds,
  prioritySupport,
}

/// Premium State
class PremiumState {
  final bool isPremium;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final String? subscriptionType; // monthly, yearly, lifetime
  final int freeTrialDaysRemaining;
  final bool hasUsedFreeTrial;
  final int paywallDismissCount;
  final DateTime? lastPaywallShown;
  
  // Engagement metrics for smart paywall timing
  final int consecutiveDaysUsed;
  final int totalDhikrCount;
  final int totalPrayersTracked;

  const PremiumState({
    this.isPremium = false,
    this.purchaseDate,
    this.expiryDate,
    this.subscriptionType,
    this.freeTrialDaysRemaining = 0,
    this.hasUsedFreeTrial = false,
    this.paywallDismissCount = 0,
    this.lastPaywallShown,
    this.consecutiveDaysUsed = 0,
    this.totalDhikrCount = 0,
    this.totalPrayersTracked = 0,
  });

  PremiumState copyWith({
    bool? isPremium,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? subscriptionType,
    int? freeTrialDaysRemaining,
    bool? hasUsedFreeTrial,
    int? paywallDismissCount,
    DateTime? lastPaywallShown,
    int? consecutiveDaysUsed,
    int? totalDhikrCount,
    int? totalPrayersTracked,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      freeTrialDaysRemaining: freeTrialDaysRemaining ?? this.freeTrialDaysRemaining,
      hasUsedFreeTrial: hasUsedFreeTrial ?? this.hasUsedFreeTrial,
      paywallDismissCount: paywallDismissCount ?? this.paywallDismissCount,
      lastPaywallShown: lastPaywallShown ?? this.lastPaywallShown,
      consecutiveDaysUsed: consecutiveDaysUsed ?? this.consecutiveDaysUsed,
      totalDhikrCount: totalDhikrCount ?? this.totalDhikrCount,
      totalPrayersTracked: totalPrayersTracked ?? this.totalPrayersTracked,
    );
  }

  /// Check if user is ready for premium upsell (psychology-based timing)
  bool get isReadyForUpsell {
    // Don't show if already premium
    if (isPremium) return false;
    
    // Don't show too frequently (wait 3 days between)
    if (lastPaywallShown != null) {
      final daysSinceLastShown = DateTime.now().difference(lastPaywallShown!).inDays;
      if (daysSinceLastShown < 3) return false;
    }
    
    // Show after user is invested (3+ days of use)
    if (consecutiveDaysUsed >= 3) return true;
    
    // Show after milestone achievements
    if (totalDhikrCount >= 100) return true;
    if (totalPrayersTracked >= 15) return true; // 3 days of prayers
    
    // Don't show if dismissed too many times recently
    if (paywallDismissCount >= 5) return false;
    
    return false;
  }
}

/// Premium Provider - Manages premium state and feature access
class PremiumNotifier extends StateNotifier<PremiumState> {
  static const String _boxName = 'premiumBox';

  PremiumNotifier() : super(const PremiumState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = await Hive.openBox(_boxName);
      final isPremium = box.get('isPremium', defaultValue: false);
      final purchaseDateMs = box.get('purchaseDate');
      final expiryDateMs = box.get('expiryDate');
      final subscriptionType = box.get('subscriptionType');
      final hasUsedFreeTrial = box.get('hasUsedFreeTrial', defaultValue: false);
      final paywallDismissCount = box.get('paywallDismissCount', defaultValue: 0);
      final lastPaywallMs = box.get('lastPaywallShown');
      final consecutiveDays = box.get('consecutiveDaysUsed', defaultValue: 0);
      final totalDhikr = box.get('totalDhikrCount', defaultValue: 0);
      final totalPrayers = box.get('totalPrayersTracked', defaultValue: 0);

      state = PremiumState(
        isPremium: isPremium,
        purchaseDate: purchaseDateMs != null 
            ? DateTime.fromMillisecondsSinceEpoch(purchaseDateMs) 
            : null,
        expiryDate: expiryDateMs != null 
            ? DateTime.fromMillisecondsSinceEpoch(expiryDateMs) 
            : null,
        subscriptionType: subscriptionType,
        hasUsedFreeTrial: hasUsedFreeTrial,
        paywallDismissCount: paywallDismissCount,
        lastPaywallShown: lastPaywallMs != null 
            ? DateTime.fromMillisecondsSinceEpoch(lastPaywallMs) 
            : null,
        consecutiveDaysUsed: consecutiveDays,
        totalDhikrCount: totalDhikr,
        totalPrayersTracked: totalPrayers,
      );

      // Check if subscription expired
      if (state.isPremium && state.expiryDate != null) {
        if (DateTime.now().isAfter(state.expiryDate!)) {
          _expireSubscription();
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _save() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put('isPremium', state.isPremium);
      await box.put('purchaseDate', state.purchaseDate?.millisecondsSinceEpoch);
      await box.put('expiryDate', state.expiryDate?.millisecondsSinceEpoch);
      await box.put('subscriptionType', state.subscriptionType);
      await box.put('hasUsedFreeTrial', state.hasUsedFreeTrial);
      await box.put('paywallDismissCount', state.paywallDismissCount);
      await box.put('lastPaywallShown', state.lastPaywallShown?.millisecondsSinceEpoch);
      await box.put('consecutiveDaysUsed', state.consecutiveDaysUsed);
      await box.put('totalDhikrCount', state.totalDhikrCount);
      await box.put('totalPrayersTracked', state.totalPrayersTracked);
    } catch (e) {
      // Silent fail
    }
  }

  /// Check if a specific feature is available
  bool hasFeature(PremiumFeature feature) {
    if (state.isPremium) return true;
    if (state.freeTrialDaysRemaining > 0) return true;
    
    // Free tier features (always available)
    switch (feature) {
      case PremiumFeature.removeAds:
        return false; // Premium only
      case PremiumFeature.allThemeColors:
        return false; // Only 2 free colors
      case PremiumFeature.unlimitedDhikrPresets:
        return false; // Only 3 free presets
      case PremiumFeature.advancedStatistics:
        return false;
      case PremiumFeature.deenMode:
        return false;
      case PremiumFeature.cloudBackup:
        return false;
      case PremiumFeature.fullDuaLibrary:
        return false; // Only 10 free duas
      case PremiumFeature.multipleTafseer:
        return false;
      default:
        return false;
    }
  }

  /// Activate premium subscription
  Future<void> activatePremium({
    required String type, // 'monthly', 'yearly', 'lifetime'
    DateTime? expiryDate,
  }) async {
    state = state.copyWith(
      isPremium: true,
      purchaseDate: DateTime.now(),
      expiryDate: expiryDate,
      subscriptionType: type,
    );
    await _save();
  }

  /// Start free trial
  Future<void> startFreeTrial() async {
    if (state.hasUsedFreeTrial) return;
    
    state = state.copyWith(
      isPremium: true,
      freeTrialDaysRemaining: 7,
      hasUsedFreeTrial: true,
      expiryDate: DateTime.now().add(const Duration(days: 7)),
      subscriptionType: 'trial',
    );
    await _save();
  }

  /// Expire subscription
  void _expireSubscription() {
    state = state.copyWith(
      isPremium: false,
      freeTrialDaysRemaining: 0,
    );
    _save();
  }

  /// Track paywall dismissal (for smart timing)
  Future<void> trackPaywallDismiss() async {
    state = state.copyWith(
      paywallDismissCount: state.paywallDismissCount + 1,
      lastPaywallShown: DateTime.now(),
    );
    await _save();
  }

  /// Track paywall view
  Future<void> trackPaywallView() async {
    state = state.copyWith(
      lastPaywallShown: DateTime.now(),
    );
    await _save();
  }

  /// Update engagement metrics
  Future<void> updateEngagement({
    int? dhikrAdded,
    int? prayersAdded,
    bool? dailyUsage,
  }) async {
    state = state.copyWith(
      totalDhikrCount: state.totalDhikrCount + (dhikrAdded ?? 0),
      totalPrayersTracked: state.totalPrayersTracked + (prayersAdded ?? 0),
      consecutiveDaysUsed: dailyUsage == true 
          ? state.consecutiveDaysUsed + 1 
          : state.consecutiveDaysUsed,
    );
    await _save();
  }

  /// Restore purchases (for app store)
  Future<bool> restorePurchases() async {
    // TODO: Implement with actual in-app purchase restoration
    // For now, this is a placeholder
    return false;
  }
}

/// Providers
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
  (ref) => PremiumNotifier(),
);

/// Helper provider for quick premium check (includes coin-based premium)
final isPremiumProvider = Provider<bool>((ref) {
  final premiumState = ref.watch(premiumProvider).isPremium;
  final coinPremium = ref.watch(hasCoinPremiumProvider);
  return premiumState || coinPremium;
});

/// Helper provider for feature access
final hasFeatureProvider = Provider.family<bool, PremiumFeature>((ref, feature) {
  return ref.watch(premiumProvider.notifier).hasFeature(feature);
});
