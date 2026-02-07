import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/premium_provider.dart';

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

  // Pricing (in INR)
  static const Map<String, Map<String, dynamic>> _plans = {
    'monthly': {
      'price': 99,
      'period': 'month',
      'savings': null,
      'badge': null,
    },
    'yearly': {
      'price': 299,
      'period': 'year',
      'savings': '75%',
      'badge': 'MOST POPULAR',
      'monthlyEquivalent': 25,
    },
    'lifetime': {
      'price': 799,
      'period': 'once',
      'savings': null,
      'badge': 'BEST VALUE',
    },
  };

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
    
    // Track paywall view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumProvider.notifier).trackPaywallView();
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

  void _subscribe() {
    HapticFeedback.mediumImpact();
    
    final planKeys = ['monthly', 'yearly', 'lifetime'];
    final selectedKey = planKeys[_selectedPlan];
    
    // TODO: Implement actual in-app purchase
    // For now, simulate purchase
    _showPurchaseSimulation(selectedKey);
  }

  void _showPurchaseSimulation(String planType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shopping_cart, color: Color(0xFFC2A366)),
            const SizedBox(width: 12),
            const Text('Purchase', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'In production, this would open Google Play billing for the $planType plan.\n\nFor testing, tap "Simulate Purchase" to unlock premium.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Simulate purchase
              DateTime? expiry;
              if (planType == 'monthly') {
                expiry = DateTime.now().add(const Duration(days: 30));
              } else if (planType == 'yearly') {
                expiry = DateTime.now().add(const Duration(days: 365));
              }
              // lifetime = no expiry
              
              await ref.read(premiumProvider.notifier).activatePremium(
                type: planType,
                expiryDate: expiry,
              );
              
              if (mounted) {
                _showSuccessAnimation();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2A366),
            ),
            child: const Text('Simulate Purchase', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

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

  void _startTrial() {
    HapticFeedback.mediumImpact();
    ref.read(premiumProvider.notifier).startFreeTrial();
    _showSuccessAnimation();
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
                        
                        // Free trial option
                        if (!premiumState.hasUsedFreeTrial)
                          _buildTrialOption(),
                        
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

  Widget _buildHeader() {
    return Column(
      children: [
        // Premium icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFC2A366),
                const Color(0xFFA67B5B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC2A366).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: 40,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Title
        const Text(
          'Unlock Your Full\nSpiritual Journey',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Subtitle
        Text(
          'Enhance your daily ibadah with premium features',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFC2A366).withValues(alpha: 0.2),
            const Color(0xFFC2A366).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC2A366).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Congratulations!',
                  style: TextStyle(
                    color: Color(0xFFC2A366),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.milestone!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Star rating
          Row(
            children: List.generate(5, (i) => const Icon(
              Icons.star,
              color: Color(0xFFFFD700),
              size: 16,
            )),
          ),
          const SizedBox(width: 8),
          Text(
            '4.9',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 16),
          Text(
            '10K+ Muslims',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      ('📿', 'Unlimited Dhikr Presets', 'Track any dhikr with custom targets'),
      ('🎨', 'All Theme Colors', '12 beautiful themes to personalize'),
      ('📊', 'Advanced Statistics', 'Detailed insights & progress tracking'),
      ('🌙', 'Deen Mode', 'Block distractions during prayer times'),
      ('🛡️', 'Hard Block Mode', 'Lock blocks permanently — no escape'),
      ('☁️', 'Cloud Backup', 'Never lose your streaks & data'),
      ('📖', 'Full Content Library', 'Complete Hadith & Dua collection'),
    ];

    return Column(
      children: features.map((f) => _buildFeatureItem(f.$1, f.$2, f.$3)).toList(),
    );
  }

  Widget _buildFeatureItem(String emoji, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFC2A366).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: Color(0xFFC2A366),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPlans() {
    final plans = ['monthly', 'yearly', 'lifetime'];
    
    return Column(
      children: List.generate(plans.length, (index) {
        final plan = _plans[plans[index]]!;
        final isSelected = _selectedPlan == index;
        final badge = plan['badge'] as String?;
        
        return GestureDetector(
          onTap: () => _selectPlan(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFFC2A366).withValues(alpha: 0.15)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected 
                    ? const Color(0xFFC2A366)
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Radio indicator
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFFC2A366)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC2A366),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                
                const SizedBox(width: 16),
                
                // Plan details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plans[index].substring(0, 1).toUpperCase() + 
                            plans[index].substring(1),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badge == 'BEST VALUE'
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : const Color(0xFFC2A366).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: badge == 'BEST VALUE'
                                      ? Colors.amber
                                      : const Color(0xFFC2A366),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (plan['monthlyEquivalent'] != null)
                        Text(
                          'Just ₹${plan['monthlyEquivalent']}/month',
                          style: TextStyle(
                            color: const Color(0xFFC2A366).withValues(alpha: 0.8),
                            fontSize: 12,
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
                      children: [
                        Text(
                          '₹${plan['price']}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '/${plan['period']}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (plan['savings'] != null)
                      Text(
                        'Save ${plan['savings']}',
                        style: const TextStyle(
                          color: Color(0xFFC2A366),
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
    );
  }

  Widget _buildCTAButton() {
    return GestureDetector(
      onTap: _subscribe,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC2A366), Color(0xFFA67B5B)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC2A366).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Continue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialOption() {
    return GestureDetector(
      onTap: _startTrial,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'Try FREE for 7 days',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadges() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 14, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(
              'Secure payment via Google Play',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Cancel anytime • Instant access',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
          ),
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
  static const _camelBrown = Color(0xFFA67B5B);
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
                          child: Text(
                            '🐪',
                            style: TextStyle(fontSize: 42),
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
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sandGold.withValues(alpha: 0.2),
                      foregroundColor: _sandGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Start Exploring  ✨',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
