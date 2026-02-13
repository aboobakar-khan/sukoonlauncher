import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/play_billing_service.dart';

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
  final int paywallDismissCount;
  final DateTime? lastPaywallShown;
  
  // Engagement metrics for smart paywall timing
  final int consecutiveDaysUsed;
  final int totalDhikrCount;
  final int totalPrayersTracked;

  // Billing state
  final bool isStoreAvailable;
  final bool isPurchasing;
  final bool isPurchasePending;
  final String? purchaseError;

  const PremiumState({
    this.isPremium = false,
    this.purchaseDate,
    this.expiryDate,
    this.subscriptionType,
    this.paywallDismissCount = 0,
    this.lastPaywallShown,
    this.consecutiveDaysUsed = 0,
    this.totalDhikrCount = 0,
    this.totalPrayersTracked = 0,
    this.isStoreAvailable = false,
    this.isPurchasing = false,
    this.isPurchasePending = false,
    this.purchaseError,
  });

  PremiumState copyWith({
    bool? isPremium,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? subscriptionType,
    int? paywallDismissCount,
    DateTime? lastPaywallShown,
    int? consecutiveDaysUsed,
    int? totalDhikrCount,
    int? totalPrayersTracked,
    bool? isStoreAvailable,
    bool? isPurchasing,
    bool? isPurchasePending,
    String? purchaseError,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      paywallDismissCount: paywallDismissCount ?? this.paywallDismissCount,
      lastPaywallShown: lastPaywallShown ?? this.lastPaywallShown,
      consecutiveDaysUsed: consecutiveDaysUsed ?? this.consecutiveDaysUsed,
      totalDhikrCount: totalDhikrCount ?? this.totalDhikrCount,
      totalPrayersTracked: totalPrayersTracked ?? this.totalPrayersTracked,
      isStoreAvailable: isStoreAvailable ?? this.isStoreAvailable,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isPurchasePending: isPurchasePending ?? this.isPurchasePending,
      purchaseError: purchaseError,
    );
  }

  /// Check if user is ready for premium upsell (psychology-based timing)
  bool get isReadyForUpsell {
    if (isPremium) return false;
    
    if (lastPaywallShown != null) {
      final daysSinceLastShown = DateTime.now().difference(lastPaywallShown!).inDays;
      if (daysSinceLastShown < 3) return false;
    }
    
    if (consecutiveDaysUsed >= 3) return true;
    if (totalDhikrCount >= 100) return true;
    if (totalPrayersTracked >= 15) return true;
    if (paywallDismissCount >= 5) return false;
    
    return false;
  }
}

/// Premium Provider — Manages premium state, feature access & Google Play Billing
/// Security: Uses hash verification on stored premium state to prevent tampering
class PremiumNotifier extends StateNotifier<PremiumState> {
  static const String _boxName = 'premiumBox';
  static const String _hashSalt = 'suk00n_l4unch3r_pr3m1um_';
  final PlayBillingService _billing = PlayBillingService();

  PremiumNotifier() : super(const PremiumState()) {
    _init();
  }

  Future<void> _init() async {
    await _load();
    await _initBilling();
  }

  /// Initialize Google Play Billing
  Future<void> _initBilling() async {
    try {
      _billing.onPurchaseUpdated = _onPurchaseDelivered;
      _billing.onPurchasePending = _onPurchasePending;
      _billing.onError = (error) {
        debugPrint('PremiumNotifier: Billing error — $error');
        state = state.copyWith(
          isPurchasing: false,
          isPurchasePending: false,
          purchaseError: error,
        );
      };

      await _billing.initialize();

      state = state.copyWith(
        isStoreAvailable: _billing.isAvailable,
      );
    } catch (e) {
      debugPrint('PremiumNotifier: Billing init failed — $e');
    }
  }

  /// Called when a purchase is pending (awaiting payment confirmation)
  void _onPurchasePending(PurchaseDetails purchase) {
    debugPrint('PremiumNotifier: Purchase pending — ${purchase.productID}');
    state = state.copyWith(
      isPurchasing: false,
      isPurchasePending: true,
      purchaseError: null,
    );
  }

  /// Called when a purchase is verified and delivered — ONLY way to activate premium
  void _onPurchaseDelivered(PurchaseDetails purchase) {
    String type;
    DateTime? expiry;

    switch (purchase.productID) {
      case PlayBillingService.monthlySubId:
        type = 'monthly';
        expiry = DateTime.now().add(const Duration(days: 30));
        break;
      case PlayBillingService.yearlySubId:
        type = 'yearly';
        expiry = DateTime.now().add(const Duration(days: 365));
        break;
      case PlayBillingService.lifetimeId:
        type = 'lifetime';
        expiry = null; // Never expires
        break;
      default:
        debugPrint('PremiumNotifier: Unknown product — ${purchase.productID}');
        return;
    }

    final now = DateTime.now();
    state = state.copyWith(
      isPremium: true,
      purchaseDate: now,
      expiryDate: expiry,
      subscriptionType: type,
      isPurchasing: false,
      isPurchasePending: false,
      purchaseError: null,
    );
    _save();
    debugPrint('PremiumNotifier: Premium activated — $type');
  }

  /// Get available products for purchase
  List<ProductDetails> get availableProducts => _billing.products;

  /// Get a specific product
  ProductDetails? getProduct(String id) => _billing.getProduct(id);

  /// Purchase a product by ID
  Future<bool> purchase(String productId) async {
    final product = _billing.getProduct(productId);
    if (product == null) {
      state = state.copyWith(purchaseError: 'Product not available. Please try again later.');
      return false;
    }

    state = state.copyWith(isPurchasing: true, purchaseError: null);

    try {
      final success = await _billing.buyProduct(product);
      if (!success) {
        state = state.copyWith(isPurchasing: false);
      }
      return success;
    } catch (e) {
      debugPrint('PremiumNotifier: Purchase error — $e');
      state = state.copyWith(
        isPurchasing: false,
        purchaseError: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    state = state.copyWith(isPurchasing: true, purchaseError: null);

    try {
      await _billing.restorePurchases();
      // Wait for the purchase stream to process
      await Future.delayed(const Duration(seconds: 3));

      if (_billing.hasAnyPremium || state.isPremium) {
        state = state.copyWith(isPurchasing: false);
        return true;
      }

      state = state.copyWith(
        isPurchasing: false,
        purchaseError: 'No previous purchases found',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isPurchasing: false,
        purchaseError: 'Could not restore purchases. Check your connection.',
      );
      return false;
    }
  }

  /// Generate verification hash for stored premium state
  String _generateHash(bool isPremium, String? type, int? purchaseMs) {
    final data = '$_hashSalt${isPremium}_${type ?? 'none'}_${purchaseMs ?? 0}';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 16);
  }

  /// Verify stored premium state hasn't been tampered with
  bool _verifyHash(String storedHash, bool isPremium, String? type, int? purchaseMs) {
    return storedHash == _generateHash(isPremium, type, purchaseMs);
  }

  Future<void> _load() async {
    try {
      final box = await Hive.openBox(_boxName);
      final isPremium = box.get('isPremium', defaultValue: false);
      final purchaseDateMs = box.get('purchaseDate');
      final expiryDateMs = box.get('expiryDate');
      final subscriptionType = box.get('subscriptionType');
      final paywallDismissCount = box.get('paywallDismissCount', defaultValue: 0);
      final lastPaywallMs = box.get('lastPaywallShown');
      final consecutiveDays = box.get('consecutiveDaysUsed', defaultValue: 0);
      final totalDhikr = box.get('totalDhikrCount', defaultValue: 0);
      final totalPrayers = box.get('totalPrayersTracked', defaultValue: 0);
      final storedHash = box.get('premiumHash', defaultValue: '');

      // Verify integrity of premium state
      bool verifiedPremium = isPremium;
      if (isPremium && storedHash.isNotEmpty) {
        if (!_verifyHash(storedHash, isPremium, subscriptionType, purchaseDateMs)) {
          debugPrint('PremiumNotifier: Hash verification failed — resetting premium');
          verifiedPremium = false;
          // Clear tampered data
          await box.put('isPremium', false);
          await box.delete('subscriptionType');
          await box.delete('purchaseDate');
          await box.delete('premiumHash');
        }
      }

      state = PremiumState(
        isPremium: verifiedPremium,
        purchaseDate: purchaseDateMs != null 
            ? DateTime.fromMillisecondsSinceEpoch(purchaseDateMs) 
            : null,
        expiryDate: expiryDateMs != null 
            ? DateTime.fromMillisecondsSinceEpoch(expiryDateMs) 
            : null,
        subscriptionType: verifiedPremium ? subscriptionType : null,
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
      debugPrint('PremiumNotifier: Load error — $e');
    }
  }

  Future<void> _save() async {
    try {
      final box = await Hive.openBox(_boxName);
      final purchaseMs = state.purchaseDate?.millisecondsSinceEpoch;
      
      await box.put('isPremium', state.isPremium);
      await box.put('purchaseDate', purchaseMs);
      await box.put('expiryDate', state.expiryDate?.millisecondsSinceEpoch);
      await box.put('subscriptionType', state.subscriptionType);
      await box.put('paywallDismissCount', state.paywallDismissCount);
      await box.put('lastPaywallShown', state.lastPaywallShown?.millisecondsSinceEpoch);
      await box.put('consecutiveDaysUsed', state.consecutiveDaysUsed);
      await box.put('totalDhikrCount', state.totalDhikrCount);
      await box.put('totalPrayersTracked', state.totalPrayersTracked);
      
      // Store verification hash
      final hash = _generateHash(state.isPremium, state.subscriptionType, purchaseMs);
      await box.put('premiumHash', hash);
    } catch (e) {
      debugPrint('PremiumNotifier: Save error — $e');
    }
  }

  /// Check if a specific feature is available
  bool hasFeature(PremiumFeature feature) {
    if (state.isPremium) return true;
    
    // All features require premium — no free tier features
    return false;
  }

  /// Expire subscription
  void _expireSubscription() {
    state = state.copyWith(
      isPremium: false,
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

  @override
  void dispose() {
    _billing.dispose();
    super.dispose();
  }
}

/// Providers
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
  (ref) => PremiumNotifier(),
);

/// Helper provider for quick premium check
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider).isPremium;
});

/// Helper provider for feature access
final hasFeatureProvider = Provider.family<bool, PremiumFeature>((ref, feature) {
  return ref.watch(premiumProvider.notifier).hasFeature(feature);
});
