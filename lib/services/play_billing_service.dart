import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// ─────────────────────────────────────────────────────────────
/// Google Play Billing Service — Production-Hardened
/// Handles subscriptions & one-time purchases via Play Store
/// ─────────────────────────────────────────────────────────────

class PlayBillingService {
  static final PlayBillingService _instance = PlayBillingService._internal();
  factory PlayBillingService() => _instance;
  PlayBillingService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ── Product IDs (must match Play Console in-app products) ──
  static const String monthlySubId = 'sukoon_premium_monthly';
  static const String yearlySubId = 'sukoon_premium_yearly';
  static const String lifetimeId = 'sukoon_premium_lifetime';

  static const Set<String> _productIds = {
    monthlySubId,
    yearlySubId,
    lifetimeId,
  };

  // ── State ──
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  List<PurchaseDetails> _purchases = [];
  int _initRetries = 0;
  static const int _maxRetries = 3;

  // Callbacks
  void Function(PurchaseDetails)? onPurchaseUpdated;
  void Function(PurchaseDetails)? onPurchasePending;
  void Function(String error)? onError;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => _products;
  List<PurchaseDetails> get purchases => _purchases;

  /// Get product by ID
  ProductDetails? getProduct(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Initialize billing — call once at app start, with retry
  Future<void> initialize() async {
    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('PlayBilling: Store not available');
        // Retry after delay if first attempt
        if (_initRetries < _maxRetries) {
          _initRetries++;
          debugPrint('PlayBilling: Retry ${'$_initRetries'}/$_maxRetries in 5s');
          await Future.delayed(const Duration(seconds: 5));
          return initialize();
        }
        return;
      }

      // Listen for purchase updates
      _subscription?.cancel();
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          debugPrint('PlayBilling: Stream error: $error');
          onError?.call('Purchase stream error');
        },
      );

      // Load products
      await _loadProducts();
      _initRetries = 0; // Reset on success

      debugPrint('PlayBilling: Initialized with ${_products.length} products');
    } catch (e) {
      debugPrint('PlayBilling: Init error: $e');
      _isAvailable = false;
    }
  }

  /// Load available products from Play Store
  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('PlayBilling: Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;

      // Sort: monthly, yearly, lifetime
      _products.sort((a, b) {
        const order = {monthlySubId: 0, yearlySubId: 1, lifetimeId: 2};
        return (order[a.id] ?? 3).compareTo(order[b.id] ?? 3);
      });

      debugPrint('PlayBilling: Loaded ${_products.length} products');
    } catch (e) {
      debugPrint('PlayBilling: Load products error: $e');
    }
  }

  /// Buy a product (subscription or one-time)
  Future<bool> buyProduct(ProductDetails product) async {
    if (!_isAvailable) {
      onError?.call('Store not available');
      return false;
    }

    try {
      final purchaseParam = PurchaseParam(productDetails: product);

      // One-time purchase for lifetime, subscription for monthly/yearly
      if (product.id == lifetimeId) {
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Subscriptions use buyNonConsumable in the in_app_purchase package
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('PlayBilling: Buy error: $e');
      onError?.call('Purchase failed. Please try again.');
      return false;
    }
  }

  /// Handle purchase updates from Google Play
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint('PlayBilling: Purchase update — ${purchase.productID}: ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify and deliver the purchase
          _deliverPurchase(purchase);
          break;

        case PurchaseStatus.error:
          final errorMsg = purchase.error?.message ?? 'Purchase failed';
          debugPrint('PlayBilling: Error — $errorMsg');
          onError?.call(errorMsg);
          break;

        case PurchaseStatus.canceled:
          debugPrint('PlayBilling: Purchase canceled by user');
          onError?.call('Purchase was canceled');
          break;

        case PurchaseStatus.pending:
          debugPrint('PlayBilling: Purchase pending — awaiting payment');
          onPurchasePending?.call(purchase);
          break;
      }

      // Complete pending purchases to acknowledge with Play Store
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// Verify and deliver the purchase
  void _deliverPurchase(PurchaseDetails purchase) {
    // Basic verification: ensure product ID is one we recognize
    if (!_productIds.contains(purchase.productID)) {
      debugPrint('PlayBilling: Unknown product ID — ${purchase.productID}');
      onError?.call('Invalid product');
      return;
    }

    _purchases.add(purchase);
    onPurchaseUpdated?.call(purchase);
    debugPrint('PlayBilling: Delivered purchase — ${purchase.productID}');
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      onError?.call('Store not available. Please check your connection.');
      return;
    }

    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('PlayBilling: Restore error: $e');
      onError?.call('Could not restore purchases. Please try again.');
    }
  }

  /// Check if user has an active purchase for a product
  bool hasPurchase(String productId) {
    return _purchases.any(
      (p) => p.productID == productId && 
             (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored),
    );
  }

  /// Check if user has any active premium purchase
  bool get hasAnyPremium {
    return hasPurchase(monthlySubId) ||
           hasPurchase(yearlySubId) ||
           hasPurchase(lifetimeId);
  }

  /// Generate a verification hash for purchase data
  static String generatePurchaseHash(String productId, int purchaseTimeMs) {
    final data = 'sukoon_${productId}_$purchaseTimeMs';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 16);
  }

  /// Verify a stored hash matches expected values
  static bool verifyPurchaseHash(String hash, String productId, int purchaseTimeMs) {
    return hash == generatePurchaseHash(productId, purchaseTimeMs);
  }

  /// Dispose
  void dispose() {
    _subscription?.cancel();
  }
}
