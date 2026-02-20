import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/premium_provider.dart';
import '../services/play_billing_service.dart';

/// Premium Paywall Screen
/// Psychology-optimized design for maximum conversion
class PremiumPaywallScreen extends ConsumerStatefulWidget {
  final String? triggerFeature; // What feature triggered this
  final String? milestone; // Milestone achieved (for celebration)

  const PremiumPaywallScreen({
    super.key,
    this.triggerFeature,
    this.milestone,
  });

  @override
  ConsumerState<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends ConsumerState<PremiumPaywallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _selectedPlan = 1; // Default to yearly (best value for us)
  bool _pricesLoaded = false;

  // ── Dynamic pricing fetched from Google Play Console ──
  // Fallback values shown only while loading or if store unavailable
  static const Map<String, Map<String, dynamic>> _fallbackPlans = {
    'monthly': {
      'price': '...',
      'period': 'month',
      'savings': null,
      'badge': null,
    },
    'yearly': {
      'price': '...',
      'period': 'year',
      'savings': null,
      'badge': 'MOST POPULAR',
      'monthlyEquivalent': null,
    },
    'lifetime': {
      'price': '...',
      'period': 'once',
      'savings': null,
      'badge': 'BEST VALUE',
    },
  };

  Map<String, Map<String, dynamic>> _plans = {
    'monthly': {'price': '...', 'period': 'month', 'savings': null, 'badge': null},
    'yearly': {'price': '...', 'period': 'year', 'savings': null, 'badge': 'MOST POPULAR', 'monthlyEquivalent': null},
    'lifetime': {'price': '...', 'period': 'once', 'savings': null, 'badge': 'BEST VALUE'},
  };

  /// Build dynamic plans from Play Store product details
  void _loadStoreProducts() {
    final billing = PlayBillingService();
    final products = billing.products;

    if (products.isEmpty) {
      _plans = Map.from(_fallbackPlans);
      _pricesLoaded = false;
      return;
    }

    final monthly = billing.getProduct(PlayBillingService.monthlySubId);
    final yearly = billing.getProduct(PlayBillingService.yearlySubId);
    final lifetime = billing.getProduct(PlayBillingService.lifetimeId);

    // Calculate savings & monthly equivalent from real prices
    String? yearlySavings;
    String? yearlyMonthlyEquivalent;
    if (monthly != null && yearly != null) {
      final monthlyRaw = monthly.rawPrice;
      final yearlyRaw = yearly.rawPrice;
      if (monthlyRaw > 0) {
        final yearlyIfMonthly = monthlyRaw * 12;
        final savedPercent = ((yearlyIfMonthly - yearlyRaw) / yearlyIfMonthly * 100).round();
        if (savedPercent > 0) yearlySavings = '$savedPercent%';
        final perMonth = (yearlyRaw / 12).ceil();
        yearlyMonthlyEquivalent = '$perMonth';
      }
    }

    _plans = {
      'monthly': {
        'price': monthly?.price ?? '...',
        'period': 'month',
        'savings': null,
        'badge': null,
        'isStorePrice': monthly != null,
      },
      'yearly': {
        'price': yearly?.price ?? '...',
        'period': 'year',
        'savings': yearlySavings,
        'badge': 'MOST POPULAR',
        'monthlyEquivalent': yearlyMonthlyEquivalent,
        'currencySymbol': yearly?.currencySymbol ?? '',
        'isStorePrice': yearly != null,
      },
      'lifetime': {
        'price': lifetime?.price ?? '...',
        'period': 'once',
        'savings': null,
        'badge': 'BEST VALUE',
        'isStorePrice': lifetime != null,
      },
    };
    _pricesLoaded = products.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _animController.forward();
    
    // Load real prices from Play Store
    _loadStoreProducts();
    
    // Track paywall view & retry loading prices if store initializing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumProvider.notifier).trackPaywallView();
      // Retry price loading after a short delay if products weren't ready
      if (!_pricesLoaded) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _loadStoreProducts());
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _selectPlan(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPlan = index);
  }

  void _subscribe() async {
    HapticFeedback.mediumImpact();
    
    final planKeys = ['monthly', 'yearly', 'lifetime'];
    final selectedKey = planKeys[_selectedPlan];
    final premiumNotifier = ref.read(premiumProvider.notifier);
    final storeAvailable = ref.read(premiumProvider).isStoreAvailable;

    if (!storeAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Play Store not available. Please try again later.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
      return;
    }

    // ── Google Play purchase ──
    String productId;
    switch (selectedKey) {
      case 'monthly':
        productId = PlayBillingService.monthlySubId;
        break;
      case 'yearly':
        productId = PlayBillingService.yearlySubId;
        break;
      case 'lifetime':
        productId = PlayBillingService.lifetimeId;
        break;
      default:
        productId = PlayBillingService.yearlySubId;
    }

    final success = await premiumNotifier.purchase(productId);
    if (!success && mounted) {
      final error = ref.read(premiumProvider).purchaseError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Purchase failed'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } else if (mounted && ref.read(premiumProvider).isPremium) {
      _showSuccessAnimation();
    }
  }

  void _restorePurchases() async {
    HapticFeedback.mediumImpact();
    final success = await ref.read(premiumProvider.notifier).restorePurchases();
    if (mounted) {
      if (success) {
        _showSuccessAnimation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No previous purchases found'),
            backgroundColor: Colors.white.withValues(alpha: 0.1),
          ),
        );
      }
    }
  }


  // Coupon codes managed via Google Play Console

  void _showSuccessAnimation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const _PremiumCelebrationPage(),
      ),
    );
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    ref.read(premiumProvider.notifier).trackPaywallDismiss();
    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    final premiumState = ref.watch(premiumProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Header with visual
                        _buildHeader(),
                        
                        const SizedBox(height: 32),
                        
                        // Milestone celebration (if applicable)
                        if (widget.milestone != null)
                          _buildMilestoneBanner(),
                        
                        // Social proof
                        _buildSocialProof(),
                        
                        const SizedBox(height: 24),
                        
                        // Features list
                        _buildFeaturesList(),
                        
                        const SizedBox(height: 32),
                        
                        // Pricing plans
                        _buildPricingPlans(),
                        
                        const SizedBox(height: 24),
                        
                        // CTA Button
                        _buildCTAButton(),
                        
                        const SizedBox(height: 16),
                        
                        // Trust badges
                        _buildTrustBadges(),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 REDESIGNED PAYWALL WIDGETS
  // ═══════════════════════════════════════════════════════════

  static const _gold = Color(0xFFC2A366);
  static const _goldLight = Color(0xFFD4AF78);
  static const _goldDark = Color(0xFF9B7B4F);

  Widget _buildHeader() {
    return Column(
      children: [
        // Layered glow rings
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _gold.withValues(alpha: 0.15),
                      _gold.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Inner icon circle
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_goldLight, _gold, _goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE8D5B7), Colors.white],
          ).createShader(bounds),
          child: const Text(
            'Sukoon Pro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Deepen your connection with Allah',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('🎉', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Congratulations!',
                  style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.milestone!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(5, (i) => Icon(
            Icons.star_rounded,
            color: const Color(0xFFFFD700),
            size: 15,
          )),
          const SizedBox(width: 6),
          Text(
            '4.9',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.12)),
          ),
          Text(
            '10K+ Muslims',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      ('📿', 'Unlimited Dhikr'),
      ('🎨', 'Premium Themes'),
      ('📊', 'Advanced Analytics'),
      ('🌙', 'Deen Mode'),
      ('🛡️', 'Hard Block'),
      ('☁️', 'Cloud Backup'),
      ('📖', 'Full Library'),
      ('✨', 'Early Access'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: features.map((f) => _buildFeatureTile(f.$1, f.$2)).toList(),
    );
  }

  Widget _buildFeatureTile(String emoji, String title) {
    return Container(
      width: (MediaQuery.of(context).size.width - 58) / 2, // 2 columns
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPlans() {
    final plans = ['monthly', 'yearly', 'lifetime'];
    
    return Column(
      children: [
        // Section label
        Row(
          children: [
            Text(
              'Choose your plan',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate(plans.length, (index) {
          final plan = _plans[plans[index]]!;
          final isSelected = _selectedPlan == index;
          final badge = plan['badge'] as String?;
          
          return GestureDetector(
            onTap: () => _selectPlan(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected 
                    ? _gold.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected 
                      ? _gold.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.06),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ] : [],
              ),
              child: Row(
                children: [
                  // Radio
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _gold : Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                      color: isSelected ? _gold.withValues(alpha: 0.15) : Colors.transparent,
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                            ),
                          )
                        : null,
                  ),
                  
                  const SizedBox(width: 14),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plans[index][0].toUpperCase() + plans[index].substring(1),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: badge == 'BEST VALUE'
                                        ? [Colors.amber.withValues(alpha: 0.25), Colors.amber.withValues(alpha: 0.1)]
                                        : [_gold.withValues(alpha: 0.25), _gold.withValues(alpha: 0.1)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    color: badge == 'BEST VALUE' ? Colors.amber : _gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (plan['monthlyEquivalent'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Just ${plan['currencySymbol'] ?? '₹'}${plan['monthlyEquivalent']}/month',
                              style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            // Play Store returns pre-formatted price (e.g. "₹99.00")
                            '${plan['price']}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '/${plan['period']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (plan['savings'] != null)
                        Text(
                          'Save ${plan['savings']}',
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCTAButton() {
    final isPurchasing = ref.watch(premiumProvider).isPurchasing;

    return Column(
      children: [
        GestureDetector(
          onTap: isPurchasing ? null : _subscribe,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPurchasing
                    ? [const Color(0xFF444444), const Color(0xFF333333)]
                    : [_goldLight, _gold, _goldDark],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isPurchasing ? [] : [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: isPurchasing
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: isPurchasing ? null : _restorePurchases,
          child: Text(
            'Restore Purchases',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadges() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, size: 13, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 5),
            Text(
              'Secured by Google Play',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Cancel anytime  •  Instant access  •  No hidden fees',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 10),
        ),
      ],
    );
  }
}

/// Show premium paywall
Future<void> showPremiumPaywall(
  BuildContext context, {
  String? triggerFeature,
  String? milestone,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, _, __) => PremiumPaywallScreen(
        triggerFeature: triggerFeature,
        milestone: milestone,
      ),
      transitionsBuilder: (context, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    ),
  );
}

/// Feature gate widget - wraps content and shows paywall if not premium
class PremiumGate extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;
  final Widget? lockedPlaceholder;

  const PremiumGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedPlaceholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasFeatureProvider(feature));

    if (hasAccess) {
      return child;
    }

    return GestureDetector(
      onTap: () => showPremiumPaywall(context, triggerFeature: feature.name),
      child: lockedPlaceholder ?? _buildDefaultLocked(),
    );
  }

  Widget _buildDefaultLocked() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            color: Colors.white.withValues(alpha: 0.4),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Premium Feature',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFC2A366).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'UNLOCK',
              style: TextStyle(
                color: Color(0xFFC2A366),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🎉 PREMIUM CELEBRATION PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class _PremiumCelebrationPage extends StatefulWidget {
  const _PremiumCelebrationPage();

  @override
  State<_PremiumCelebrationPage> createState() =>
      _PremiumCelebrationPageState();
}

class _PremiumCelebrationPageState extends State<_PremiumCelebrationPage>
    with TickerProviderStateMixin {
  static const _sandGold = Color(0xFFC2A366);
  static const _warmBrown = Color(0xFFA67B5B);
  static const _desertSunset = Color(0xFFE8915A);

  late AnimationController _scaleCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _sparkleCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scaleCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _sparkleCtrl.repeat(reverse: true);
    });
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _fadeCtrl.dispose();
    _sparkleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Animated badge
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _sandGold.withValues(alpha: 0.3),
                        _sandGold.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _sparkleCtrl,
                      builder: (_, child) => Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(
                            color: _sandGold.withValues(
                                alpha: 0.4 + _sparkleCtrl.value * 0.4),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _sandGold.withValues(
                                  alpha: 0.15 + _sparkleCtrl.value * 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 42,
                            color: _sandGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              FadeTransition(
                opacity: _fadeAnim,
                child: const Column(
                  children: [
                    Text(
                      'You\'re a Pro Member!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Jazak Allahu Khayran 🤲',
                      style: TextStyle(
                        color: _sandGold,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'All premium features are now unlocked',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Unlocked features
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _sandGold.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      _celebrationFeature('📿', 'Unlimited Dhikr Presets'),
                      _celebrationFeature('🎨', 'All Theme Colors'),
                      _celebrationFeature('📊', 'Advanced Statistics'),
                      _celebrationFeature('🛡️', 'Hard Block Mode'),
                      _celebrationFeature('☁️', 'Cloud Backup'),
                      _celebrationFeature('📖', 'Full Content Library'),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              // CTA button
              FadeTransition(
                opacity: _fadeAnim,
                child: SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF78), Color(0xFFC2A366), Color(0xFF9B7B4F)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _sandGold.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Start Exploring  ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _celebrationFeature(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: _sandGold.withValues(alpha: 0.6),
            size: 18,
          ),
        ],
      ),
    );
  }
}
