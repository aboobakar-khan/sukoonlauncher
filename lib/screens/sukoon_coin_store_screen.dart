import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sukoon_coin_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/swipe_back_wrapper.dart';

// ─── Sukoon Coin Store ───────────────────────────────────────────────────────
// Inspired by: Duolingo Shop, Forest app, Habitica store
// Psychology: variable reward, loss aversion, endowed progress effect,
//   collection instinct, social proof via badges
// ────────────────────────────────────────────────────────────────────────────

const Color _gold = Color(0xFFC2A366);
const Color _brown = Color(0xFFA67B5B);
const Color _bg = Color(0xFF0A0A0A);
const Color _card = Color(0xFF141414);
const Color _cardLight = Color(0xFF1A1A1A);

class SukoonCoinStoreScreen extends ConsumerStatefulWidget {
  const SukoonCoinStoreScreen({super.key});

  @override
  ConsumerState<SukoonCoinStoreScreen> createState() => _SukoonCoinStoreScreenState();
}

class _SukoonCoinStoreScreenState extends ConsumerState<SukoonCoinStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showHistory = false;

  static const _tabs = [
    StoreCategory.premium,
    StoreCategory.themes,
    StoreCategory.clockStyles,
    StoreCategory.dhikrSkins,
    StoreCategory.soundPacks,
    StoreCategory.widgetStyles,
    StoreCategory.titles,
  ];

  static const _tabLabels = [
    'Premium',
    'Themes',
    'Clocks',
    'Dhikr',
    'Sounds',
    'Widgets',
    'Titles',
  ];

  static const _tabEmojis = [
    '👑',
    '🎨',
    '🕐',
    '📿',
    '🎵',
    '🧩',
    '🏅',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coinState = ref.watch(sukoonCoinProvider);

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(coinState),
              const SizedBox(height: 4),
              _buildBalanceCard(coinState),
              const SizedBox(height: 12),
              if (_showHistory)
                Expanded(child: _buildHistoryView(coinState))
              else ...[
                _buildTabBar(),
                Expanded(child: _buildTabContent(coinState)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────

  Widget _buildHeader(SukoonCoinState coinState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.arrow_back_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Sukoon Store',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // History toggle
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showHistory = !_showHistory);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _showHistory ? _gold.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showHistory ? _gold.withValues(alpha: 0.3) : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showHistory ? Icons.store_rounded : Icons.receipt_long_rounded,
                    color: _showHistory ? _gold : Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showHistory ? 'Store' : 'History',
                    style: TextStyle(
                      color: _showHistory ? _gold : Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Balance Card ─────────────────────────────────────────────

  Widget _buildBalanceCard(SukoonCoinState coinState) {
    final notifier = ref.read(sukoonCoinProvider.notifier);
    final hasCoinPremium = notifier.hasCoinPremium;
    final premiumExpiry = notifier.coinPremiumExpiry;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gold.withValues(alpha: 0.12), _brown.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Coin icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_gold, _brown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: _gold.withValues(alpha: 0.3), blurRadius: 12),
                  ],
                ),
                child: const Center(
                  child: Text('🪙', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${coinState.balance}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sukoon Coins',
                      style: TextStyle(
                        color: _gold.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Stats column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMiniStat('Earned', coinState.totalEarned, Icons.trending_up_rounded, const Color(0xFF7BAE6E)),
                  const SizedBox(height: 4),
                  _buildMiniStat('Spent', coinState.totalSpent, Icons.shopping_bag_rounded, const Color(0xFFE8915A)),
                ],
              ),
            ],
          ),
          // Streak + Premium status
          if (coinState.loginStreak > 1 || hasCoinPremium) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (coinState.loginStreak > 1) ...[
                    Text('🔥', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${coinState.loginStreak} day streak',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (coinState.loginStreak > 1 && hasCoinPremium)
                    Container(
                      width: 1, height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  if (hasCoinPremium) ...[
                    const Text('👑', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      'Premium · ${premiumExpiry != null ? "${premiumExpiry.difference(DateTime.now()).inDays}d left" : "Active"}',
                      style: TextStyle(
                        color: _gold.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.6), size: 13),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────────

  Widget _buildTabBar() {
    return SizedBox(
      height: 38,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _gold,
        indicatorWeight: 2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.only(left: 8),
        onTap: (_) => HapticFeedback.selectionClick(),
        tabs: List.generate(_tabs.length, (i) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_tabEmojis[i], style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  _tabLabels[i],
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
      ),
    );
  }

  // ─── Tab Content ──────────────────────────────────────────────

  Widget _buildTabContent(SukoonCoinState coinState) {
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((category) {
        final items = SukoonStore.byCategory(category);
        if (category == StoreCategory.premium) {
          return _buildPremiumSection(coinState, items);
        }
        return _buildItemGrid(coinState, items);
      }).toList(),
    );
  }

  // ─── Premium Section (special design) ─────────────────────────

  Widget _buildPremiumSection(SukoonCoinState coinState, List<StoreItem> items) {
    final item = items.first;
    final notifier = ref.read(sukoonCoinProvider.notifier);
    final hasCoinPremium = notifier.hasCoinPremium;
    final premiumExpiry = notifier.coinPremiumExpiry;
    final canAfford = coinState.balance >= item.price;
    final regularPremium = ref.watch(premiumProvider).isPremium;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Premium card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _gold.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasCoinPremium || regularPremium
                    ? _gold.withValues(alpha: 0.4)
                    : _gold.withValues(alpha: 0.12),
                width: hasCoinPremium || regularPremium ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                // Crown icon
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_gold.withValues(alpha: 0.2), _brown.withValues(alpha: 0.1)],
                    ),
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Premium Pass',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '30 days of all features unlocked',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Features list
                _buildPremiumFeature('All theme colors', Icons.palette_rounded),
                _buildPremiumFeature('All clock styles', Icons.schedule_rounded),
                _buildPremiumFeature('Unlimited dhikr presets', Icons.all_inclusive_rounded),
                _buildPremiumFeature('Advanced statistics', Icons.insights_rounded),
                _buildPremiumFeature('Full dua library', Icons.auto_stories_rounded),
                _buildPremiumFeature('Multiple tafseer', Icons.menu_book_rounded),
                _buildPremiumFeature('Deen Mode', Icons.mosque_rounded),
                _buildPremiumFeature('Ad-free experience', Icons.block_rounded),
                const SizedBox(height: 24),
                // Status or Buy button
                if (regularPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7BAE6E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7BAE6E).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: const Color(0xFF7BAE6E), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Premium Active',
                          style: TextStyle(
                            color: const Color(0xFF7BAE6E).withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (hasCoinPremium)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _gold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'Active · ${premiumExpiry != null ? "${premiumExpiry.difference(DateTime.now()).inDays} days left" : ""}',
                              style: TextStyle(
                                color: _gold.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Extend button
                      if (canAfford)
                        _buildPurchaseButton(item, coinState, label: 'Extend +30 days'),
                    ],
                  )
                else
                  _buildPurchaseButton(item, coinState),

                const SizedBox(height: 16),
                // Progress indicator to premium
                if (!regularPremium && !hasCoinPremium) ...[
                  _buildProgressToPremium(coinState.balance, item.price),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // How to earn section
          _buildHowToEarnSection(),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _gold.withValues(alpha: 0.6), size: 18),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressToPremium(int balance, int target) {
    final progress = (balance / target).clamp(0.0, 1.0);
    final remaining = target - balance;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress to Premium',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$balance / $target 🪙',
                style: TextStyle(
                  color: _gold.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(_gold.withValues(alpha: 0.8)),
              minHeight: 6,
            ),
          ),
          if (remaining > 0) ...[
            const SizedBox(height: 8),
            Text(
              '~${(remaining / 50).ceil()} days of consistent practice',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHowToEarnSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'How to Earn Coins',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildEarnRow('🕌', 'Complete all 5 prayers', '+25/day'),
          _buildEarnRow('✅', 'Complete daily challenges', '+15/day'),
          _buildEarnRow('📿', '100+ dhikr in a day', '+10/day'),
          _buildEarnRow('📖', 'Read Quran daily', '+8/day'),
          _buildEarnRow('⏱️', 'Focus sessions', '+5 each (max 3)'),
          _buildEarnRow('🔥', '7-day streak', '+50 bonus'),
          _buildEarnRow('🏆', '30-day streak', '+200 bonus'),
          _buildEarnRow('📱', 'Daily login', '+3/day'),
        ],
      ),
    );
  }

  Widget _buildEarnRow(String emoji, String label, String reward) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              reward,
              style: TextStyle(
                color: _gold.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Item Grid (for non-premium categories) ───────────────────

  Widget _buildItemGrid(SukoonCoinState coinState, List<StoreItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final owned = coinState.ownsItem(item.id);
        final canAfford = coinState.balance >= item.price;

        return _buildStoreItemCard(item, owned, canAfford, coinState);
      },
    );
  }

  Widget _buildStoreItemCard(StoreItem item, bool owned, bool canAfford, SukoonCoinState coinState) {
    // Check if this item is currently equipped
    bool isEquipped = false;
    if (item.category == StoreCategory.titles) {
      isEquipped = coinState.activeTitle == item.id;
    } else if (item.category == StoreCategory.dhikrSkins) {
      isEquipped = coinState.activeDhikrSkin == item.id;
    } else if (item.category == StoreCategory.widgetStyles) {
      isEquipped = coinState.activeWidgetStyle == item.id;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (owned) {
          _showEquipSheet(item, isEquipped);
        } else {
          _showPurchaseSheet(item, coinState);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEquipped
                ? _gold.withValues(alpha: 0.4)
                : owned
                    ? const Color(0xFF7BAE6E).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
            width: isEquipped ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji icon
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: owned
                    ? _gold.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 10),
            // Name
            Text(
              item.name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: owned ? 0.9 : 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            // Description
            Text(
              item.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // Price or Status
            if (isEquipped)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'EQUIPPED',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else if (owned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF7BAE6E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OWNED',
                  style: TextStyle(
                    color: const Color(0xFF7BAE6E).withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: canAfford
                      ? _gold.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 3),
                    Text(
                      '${item.price}',
                      style: TextStyle(
                        color: canAfford ? _gold : Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Purchase Sheet ───────────────────────────────────────────

  Widget _buildPurchaseButton(StoreItem item, SukoonCoinState coinState, {String? label}) {
    final canAfford = coinState.balance >= item.price;

    return GestureDetector(
      onTap: canAfford
          ? () => _confirmPurchase(item)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: canAfford
              ? LinearGradient(colors: [_gold, _brown])
              : null,
          color: canAfford ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          boxShadow: canAfford
              ? [BoxShadow(color: _gold.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label ?? '${item.price} — ${canAfford ? "Get Now" : "Not enough coins"}',
              style: TextStyle(
                color: canAfford ? const Color(0xFF0A0A0A) : Colors.white.withValues(alpha: 0.3),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseSheet(StoreItem item, SukoonCoinState coinState) {
    final canAfford = coinState.balance >= item.price;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Item display
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.description,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Balance display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your balance: ',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                ),
                const Text('🪙', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  '${coinState.balance}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (!canAfford) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(need ${item.price - coinState.balance} more)',
                    style: TextStyle(
                      color: const Color(0xFFE8915A).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            // Purchase button
            GestureDetector(
              onTap: canAfford ? () {
                Navigator.pop(ctx);
                _confirmPurchase(item);
              } : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: canAfford ? LinearGradient(colors: [_gold, _brown]) : null,
                  color: canAfford ? null : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    canAfford ? 'Purchase for 🪙 ${item.price}' : 'Not enough coins',
                    style: TextStyle(
                      color: canAfford ? const Color(0xFF0A0A0A) : Colors.white.withValues(alpha: 0.3),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Cancel
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPurchase(StoreItem item) async {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(sukoonCoinProvider.notifier);
    final success = await notifier.purchaseItem(item);

    if (!mounted) return;

    if (success) {
      // If premium purchased, also activate in premium provider
      if (item.category == StoreCategory.premium) {
        final premiumNotifier = ref.read(premiumProvider.notifier);
        final expiry = notifier.coinPremiumExpiry;
        await premiumNotifier.activatePremium(
          type: 'coins',
          expiryDate: expiry,
        );
      }

      HapticFeedback.heavyImpact();
      _showPurchaseSuccessDialog(item);
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Purchase failed — not enough coins'),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showPurchaseSuccessDialog(StoreItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Celebration
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(item.emoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Purchase Complete!',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '${item.name} is now yours',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
              ),
              if (item.category == StoreCategory.premium) ...[
                const SizedBox(height: 6),
                Text(
                  'All premium features unlocked for 30 days!',
                  style: TextStyle(color: _gold.withValues(alpha: 0.7), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Alhamdulillah',
                    style: TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Equip Sheet ──────────────────────────────────────────────

  void _showEquipSheet(StoreItem item, bool isCurrentlyEquipped) {
    // Only titles, dhikr skins, widget styles can be equipped
    final canEquip = [
      StoreCategory.titles,
      StoreCategory.dhikrSkins,
      StoreCategory.widgetStyles,
    ].contains(item.category);

    if (!canEquip) {
      // Show "already owned" toast for non-equippable items
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} — Already owned ✓'),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(item.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            // Equip / Unequip
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                final notifier = ref.read(sukoonCoinProvider.notifier);
                if (isCurrentlyEquipped) {
                  // Unequip
                  if (item.category == StoreCategory.titles) notifier.equipTitle(null);
                  if (item.category == StoreCategory.dhikrSkins) notifier.equipDhikrSkin(null);
                  if (item.category == StoreCategory.widgetStyles) notifier.equipWidgetStyle(null);
                } else {
                  // Equip
                  if (item.category == StoreCategory.titles) notifier.equipTitle(item.id);
                  if (item.category == StoreCategory.dhikrSkins) notifier.equipDhikrSkin(item.id);
                  if (item.category == StoreCategory.widgetStyles) notifier.equipWidgetStyle(item.id);
                }
                Navigator.pop(ctx);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isCurrentlyEquipped
                      ? Colors.white.withValues(alpha: 0.08)
                      : _gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isCurrentlyEquipped ? 'Unequip' : 'Equip',
                    style: TextStyle(
                      color: isCurrentlyEquipped
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF0A0A0A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ─── History View ─────────────────────────────────────────────

  Widget _buildHistoryView(SukoonCoinState coinState) {
    if (coinState.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📜', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No transactions yet',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Start earning coins through daily worship!',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: coinState.history.length,
      separatorBuilder: (_, __) => Divider(
        color: Colors.white.withValues(alpha: 0.04),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final tx = coinState.history[index];
        final isEarning = tx.amount > 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isEarning
                      ? const Color(0xFF7BAE6E).withValues(alpha: 0.1)
                      : const Color(0xFFE8915A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEarning ? Icons.add_rounded : Icons.remove_rounded,
                  color: isEarning ? const Color(0xFF7BAE6E) : const Color(0xFFE8915A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(tx.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${isEarning ? "+" : ""}${tx.amount}',
                style: TextStyle(
                  color: isEarning ? const Color(0xFF7BAE6E) : const Color(0xFFE8915A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              const Text('🪙', style: TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
