import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ─── Sukoon Coin Economy ─────────────────────────────────────────────────────
// Designed so a consistent 30-day prayer person earns enough for premium.
//
// EARNING RATES (daily max ~45-80 coins):
//   • Complete all 5 prayers:        25 coins/day
//   • Complete daily challenges:     15 coins (all 4)
//   • 100+ dhikr count:             10 coins/day
//   • Quran reading (1+ page):       8 coins/day
//   • 7-day login streak bonus:     50 coins (weekly)
//   • 30-day streak bonus:         200 coins (monthly)
//   • Pomodoro session complete:     5 coins each (max 3/day = 15)
//
// 30-day dedicated user earns: ~1500-2100 coins
// Premium costs: 1500 coins (30 days)
// This ensures ONLY consistent, dedicated users can afford it.
//
// SPENDING:
//   • Premium 30-day:     1500 🪙
//   • Theme colors:        150 🪙 each
//   • Clock styles:        120 🪙 each
//   • Dhikr skins:         200 🪙 each
//   • Sound packs:         180 🪙 each
//   • Widget styles:       250 🪙 each
//   • Titles/Badges:       100 🪙 each
// ────────────────────────────────────────────────────────────────────────────

/// Types of coin transactions
enum CoinTransactionType {
  // Earning
  dailyPrayer,
  dailyChallenge,
  dhikrMilestone,
  quranReading,
  streakBonus,
  pomodoroComplete,
  loginBonus,
  firstTimeBuyer, // 0-cost, just tracking

  // Spending
  purchaseTheme,
  purchaseClockStyle,
  purchaseDhikrSkin,
  purchaseSoundPack,
  purchaseWidgetStyle,
  purchaseTitle,
  purchasePremium,
}

/// A single coin transaction record
class CoinTransaction {
  final String id;
  final CoinTransactionType type;
  final int amount; // positive = earned, negative = spent
  final String description;
  final DateTime timestamp;
  final String? itemId; // which item was purchased

  const CoinTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.itemId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'amount': amount,
    'description': description,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'itemId': itemId,
  };

  factory CoinTransaction.fromJson(Map<String, dynamic> json) => CoinTransaction(
    id: json['id'] as String,
    type: CoinTransactionType.values[json['type'] as int],
    amount: json['amount'] as int,
    description: json['description'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    itemId: json['itemId'] as String?,
  );
}

/// Store item categories
enum StoreCategory {
  premium,
  themes,
  clockStyles,
  dhikrSkins,
  soundPacks,
  widgetStyles,
  titles,
}

/// A purchasable store item
class StoreItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int price;
  final StoreCategory category;
  final bool isConsumable; // false = permanent, true = timed
  final int? durationDays; // for timed items like premium

  const StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.price,
    required this.category,
    this.isConsumable = false,
    this.durationDays,
  });
}

/// All store items definition
class SukoonStore {
  static const List<StoreItem> allItems = [
    // ─── Premium ───
    StoreItem(
      id: 'premium_30d',
      name: 'Premium Pass',
      description: '30 days of all features unlocked',
      emoji: '👑',
      price: 1500,
      category: StoreCategory.premium,
      isConsumable: true,
      durationDays: 30,
    ),

    // ─── Theme Colors ───
    StoreItem(
      id: 'theme_purple',
      name: 'Royal Purple',
      description: 'Elegant purple accent theme',
      emoji: '💜',
      price: 150,
      category: StoreCategory.themes,
    ),
    StoreItem(
      id: 'theme_green',
      name: 'Oasis Green',
      description: 'Fresh nature-inspired theme',
      emoji: '💚',
      price: 150,
      category: StoreCategory.themes,
    ),
    StoreItem(
      id: 'theme_blue',
      name: 'Ocean Blue',
      description: 'Calm oceanic blue theme',
      emoji: '💙',
      price: 150,
      category: StoreCategory.themes,
    ),
    StoreItem(
      id: 'theme_orange',
      name: 'Sunset Orange',
      description: 'Warm desert sunset theme',
      emoji: '🧡',
      price: 150,
      category: StoreCategory.themes,
    ),
    StoreItem(
      id: 'theme_pink',
      name: 'Rose Pink',
      description: 'Gentle rose-tinted theme',
      emoji: '💗',
      price: 150,
      category: StoreCategory.themes,
    ),
    StoreItem(
      id: 'theme_cyan',
      name: 'Arctic Cyan',
      description: 'Cool icy cyan theme',
      emoji: '🩵',
      price: 150,
      category: StoreCategory.themes,
    ),
    StoreItem(
      id: 'theme_amber',
      name: 'Golden Amber',
      description: 'Rich golden amber theme',
      emoji: '💛',
      price: 150,
      category: StoreCategory.themes,
    ),

    // ─── Clock Styles ───
    StoreItem(
      id: 'clock_analog',
      name: 'Analog Clock',
      description: 'Classic analog face',
      emoji: '🕐',
      price: 120,
      category: StoreCategory.clockStyles,
    ),
    StoreItem(
      id: 'clock_bold',
      name: 'Bold Clock',
      description: 'Large prominent display',
      emoji: '🔤',
      price: 120,
      category: StoreCategory.clockStyles,
    ),
    StoreItem(
      id: 'clock_modern',
      name: 'Modern Clock',
      description: 'Sleek contemporary style',
      emoji: '⌚',
      price: 120,
      category: StoreCategory.clockStyles,
    ),
    StoreItem(
      id: 'clock_retro',
      name: 'Retro Clock',
      description: 'Vintage flip-clock vibes',
      emoji: '📟',
      price: 120,
      category: StoreCategory.clockStyles,
    ),
    StoreItem(
      id: 'clock_elegant',
      name: 'Elegant Clock',
      description: 'Refined sophisticated style',
      emoji: '✨',
      price: 120,
      category: StoreCategory.clockStyles,
    ),
    StoreItem(
      id: 'clock_binary',
      name: 'Binary Clock',
      description: 'Geek mode — binary time',
      emoji: '🤖',
      price: 120,
      category: StoreCategory.clockStyles,
    ),

    // ─── Dhikr Counter Skins ───
    StoreItem(
      id: 'dhikr_midnight',
      name: 'Midnight Tasbih',
      description: 'Deep dark counting theme',
      emoji: '🌙',
      price: 200,
      category: StoreCategory.dhikrSkins,
    ),
    StoreItem(
      id: 'dhikr_garden',
      name: 'Jannah Garden',
      description: 'Lush green garden counter',
      emoji: '🌿',
      price: 200,
      category: StoreCategory.dhikrSkins,
    ),
    StoreItem(
      id: 'dhikr_ocean',
      name: 'Ocean Depths',
      description: 'Calming blue ocean counter',
      emoji: '🌊',
      price: 200,
      category: StoreCategory.dhikrSkins,
    ),
    StoreItem(
      id: 'dhikr_sunset',
      name: 'Desert Sunset',
      description: 'Warm gradient counter',
      emoji: '🌅',
      price: 200,
      category: StoreCategory.dhikrSkins,
    ),

    // ─── Sound Packs ───
    StoreItem(
      id: 'sound_night',
      name: 'Desert Night',
      description: 'Crickets & gentle breeze',
      emoji: '🏜️',
      price: 180,
      category: StoreCategory.soundPacks,
    ),
    StoreItem(
      id: 'sound_birds',
      name: 'Morning Birds',
      description: 'Dawn chorus ambience',
      emoji: '🐦',
      price: 180,
      category: StoreCategory.soundPacks,
    ),
    StoreItem(
      id: 'sound_ocean',
      name: 'Ocean Waves',
      description: 'Rhythmic ocean waves',
      emoji: '🌊',
      price: 180,
      category: StoreCategory.soundPacks,
    ),
    StoreItem(
      id: 'sound_wind',
      name: 'Mountain Wind',
      description: 'Peaceful mountain breeze',
      emoji: '🏔️',
      price: 180,
      category: StoreCategory.soundPacks,
    ),

    // ─── Widget Styles ───
    StoreItem(
      id: 'widget_glass',
      name: 'Glassmorphism',
      description: 'Frosted glass widget cards',
      emoji: '🔮',
      price: 250,
      category: StoreCategory.widgetStyles,
    ),
    StoreItem(
      id: 'widget_neon',
      name: 'Neon Glow',
      description: 'Subtle neon-edge widgets',
      emoji: '💡',
      price: 250,
      category: StoreCategory.widgetStyles,
    ),
    StoreItem(
      id: 'widget_minimal',
      name: 'Ultra Minimal',
      description: 'Borderless flat widgets',
      emoji: '▫️',
      price: 250,
      category: StoreCategory.widgetStyles,
    ),

    // ─── Titles & Badges ───
    StoreItem(
      id: 'title_mumin',
      name: 'Al-Mu\'min',
      description: 'The Faithful One — profile title',
      emoji: '🕋',
      price: 100,
      category: StoreCategory.titles,
    ),
    StoreItem(
      id: 'title_hafiz',
      name: 'Hafiz',
      description: 'The Memorizer — profile title',
      emoji: '📖',
      price: 100,
      category: StoreCategory.titles,
    ),
    StoreItem(
      id: 'title_salik',
      name: 'Salik',
      description: 'The Traveler — profile title',
      emoji: '🐪',
      price: 100,
      category: StoreCategory.titles,
    ),
    StoreItem(
      id: 'title_warrior',
      name: 'Mujahid',
      description: 'The Striver — profile title',
      emoji: '⚔️',
      price: 100,
      category: StoreCategory.titles,
    ),
    StoreItem(
      id: 'title_scholar',
      name: 'Talib al-Ilm',
      description: 'The Knowledge Seeker',
      emoji: '🎓',
      price: 100,
      category: StoreCategory.titles,
    ),
  ];

  static List<StoreItem> byCategory(StoreCategory cat) =>
      allItems.where((i) => i.category == cat).toList();
}

/// Sukoon Coin state
class SukoonCoinState {
  final int balance;
  final List<CoinTransaction> history;
  final Set<String> ownedItems; // item IDs the user has purchased
  final Map<String, DateTime> timedItems; // itemId → expiry for consumable items
  final String? activeTitle; // currently equipped title
  final String? activeDhikrSkin;
  final String? activeWidgetStyle;
  final int totalEarned;
  final int totalSpent;
  final int loginStreak;
  final String? lastLoginDate; // YYYY-MM-DD
  final String? lastDailyPrayerDate;
  final String? lastDailyChallengeDate;
  final String? lastDhikrMilestoneDate;
  final String? lastQuranReadDate;
  final int pomodoroCoinsToday;
  final String? lastPomodoroDate;

  const SukoonCoinState({
    this.balance = 0,
    this.history = const [],
    this.ownedItems = const {},
    this.timedItems = const {},
    this.activeTitle,
    this.activeDhikrSkin,
    this.activeWidgetStyle,
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.loginStreak = 0,
    this.lastLoginDate,
    this.lastDailyPrayerDate,
    this.lastDailyChallengeDate,
    this.lastDhikrMilestoneDate,
    this.lastQuranReadDate,
    this.pomodoroCoinsToday = 0,
    this.lastPomodoroDate,
  });

  SukoonCoinState copyWith({
    int? balance,
    List<CoinTransaction>? history,
    Set<String>? ownedItems,
    Map<String, DateTime>? timedItems,
    String? activeTitle,
    String? activeDhikrSkin,
    String? activeWidgetStyle,
    int? totalEarned,
    int? totalSpent,
    int? loginStreak,
    String? lastLoginDate,
    String? lastDailyPrayerDate,
    String? lastDailyChallengeDate,
    String? lastDhikrMilestoneDate,
    String? lastQuranReadDate,
    int? pomodoroCoinsToday,
    String? lastPomodoroDate,
  }) {
    return SukoonCoinState(
      balance: balance ?? this.balance,
      history: history ?? this.history,
      ownedItems: ownedItems ?? this.ownedItems,
      timedItems: timedItems ?? this.timedItems,
      activeTitle: activeTitle ?? this.activeTitle,
      activeDhikrSkin: activeDhikrSkin ?? this.activeDhikrSkin,
      activeWidgetStyle: activeWidgetStyle ?? this.activeWidgetStyle,
      totalEarned: totalEarned ?? this.totalEarned,
      totalSpent: totalSpent ?? this.totalSpent,
      loginStreak: loginStreak ?? this.loginStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      lastDailyPrayerDate: lastDailyPrayerDate ?? this.lastDailyPrayerDate,
      lastDailyChallengeDate: lastDailyChallengeDate ?? this.lastDailyChallengeDate,
      lastDhikrMilestoneDate: lastDhikrMilestoneDate ?? this.lastDhikrMilestoneDate,
      lastQuranReadDate: lastQuranReadDate ?? this.lastQuranReadDate,
      pomodoroCoinsToday: pomodoroCoinsToday ?? this.pomodoroCoinsToday,
      lastPomodoroDate: lastPomodoroDate ?? this.lastPomodoroDate,
    );
  }

  bool ownsItem(String itemId) => ownedItems.contains(itemId);

  bool isItemExpired(String itemId) {
    final expiry = timedItems[itemId];
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }
}

/// Sukoon Coin Notifier — manages the entire coin economy
class SukoonCoinNotifier extends StateNotifier<SukoonCoinState> {
  // NOTE: Keep legacy box name 'camel_coins' to preserve existing user data
  static const String _boxName = 'camel_coins';

  SukoonCoinNotifier() : super(const SukoonCoinState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final box = await Hive.openBox(_boxName);
      final balance = box.get('balance', defaultValue: 0) as int;
      final totalEarned = box.get('totalEarned', defaultValue: 0) as int;
      final totalSpent = box.get('totalSpent', defaultValue: 0) as int;
      final loginStreak = box.get('loginStreak', defaultValue: 0) as int;
      final lastLoginDate = box.get('lastLoginDate') as String?;
      final lastDailyPrayerDate = box.get('lastDailyPrayerDate') as String?;
      final lastDailyChallengeDate = box.get('lastDailyChallengeDate') as String?;
      final lastDhikrMilestoneDate = box.get('lastDhikrMilestoneDate') as String?;
      final lastQuranReadDate = box.get('lastQuranReadDate') as String?;
      final pomodoroCoinsToday = box.get('pomodoroCoinsToday', defaultValue: 0) as int;
      final lastPomodoroDate = box.get('lastPomodoroDate') as String?;
      final activeTitle = box.get('activeTitle') as String?;
      final activeDhikrSkin = box.get('activeDhikrSkin') as String?;
      final activeWidgetStyle = box.get('activeWidgetStyle') as String?;

      // Load owned items
      final ownedList = box.get('ownedItems', defaultValue: <String>[]);
      final ownedItems = Set<String>.from(ownedList is List ? ownedList.cast<String>() : <String>[]);

      // Load timed items
      final timedRaw = box.get('timedItems', defaultValue: <String, int>{});
      final timedItems = <String, DateTime>{};
      if (timedRaw is Map) {
        for (final entry in timedRaw.entries) {
          timedItems[entry.key as String] = DateTime.fromMillisecondsSinceEpoch(entry.value as int);
        }
      }

      // Load transaction history (last 50 only for performance)
      final historyRaw = box.get('history', defaultValue: <dynamic>[]);
      final history = <CoinTransaction>[];
      if (historyRaw is List) {
        for (final item in historyRaw.take(50)) {
          if (item is Map) {
            try {
              history.add(CoinTransaction.fromJson(Map<String, dynamic>.from(item)));
            } catch (_) {}
          }
        }
      }

      state = SukoonCoinState(
        balance: balance,
        history: history,
        ownedItems: ownedItems,
        timedItems: timedItems,
        activeTitle: activeTitle,
        activeDhikrSkin: activeDhikrSkin,
        activeWidgetStyle: activeWidgetStyle,
        totalEarned: totalEarned,
        totalSpent: totalSpent,
        loginStreak: loginStreak,
        lastLoginDate: lastLoginDate,
        lastDailyPrayerDate: lastDailyPrayerDate,
        lastDailyChallengeDate: lastDailyChallengeDate,
        lastDhikrMilestoneDate: lastDhikrMilestoneDate,
        lastQuranReadDate: lastQuranReadDate,
        pomodoroCoinsToday: pomodoroCoinsToday,
        lastPomodoroDate: lastPomodoroDate,
      );

      // Process daily login
      _processLoginBonus();
      // Expire timed items
      _expireTimedItems();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put('balance', state.balance);
      await box.put('totalEarned', state.totalEarned);
      await box.put('totalSpent', state.totalSpent);
      await box.put('loginStreak', state.loginStreak);
      await box.put('lastLoginDate', state.lastLoginDate);
      await box.put('lastDailyPrayerDate', state.lastDailyPrayerDate);
      await box.put('lastDailyChallengeDate', state.lastDailyChallengeDate);
      await box.put('lastDhikrMilestoneDate', state.lastDhikrMilestoneDate);
      await box.put('lastQuranReadDate', state.lastQuranReadDate);
      await box.put('pomodoroCoinsToday', state.pomodoroCoinsToday);
      await box.put('lastPomodoroDate', state.lastPomodoroDate);
      await box.put('activeTitle', state.activeTitle);
      await box.put('activeDhikrSkin', state.activeDhikrSkin);
      await box.put('activeWidgetStyle', state.activeWidgetStyle);
      await box.put('ownedItems', state.ownedItems.toList());

      // Save timed items as ms
      final timedMap = <String, int>{};
      for (final entry in state.timedItems.entries) {
        timedMap[entry.key] = entry.value.millisecondsSinceEpoch;
      }
      await box.put('timedItems', timedMap);

      // Save history (last 50)
      await box.put('history', state.history.take(50).map((t) => t.toJson()).toList());
    } catch (_) {}
  }

  String get _today => DateTime.now().toIso8601String().split('T')[0];
  String get _yesterday => DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

  /// Process login bonus
  void _processLoginBonus() {
    if (state.lastLoginDate == _today) return; // Already logged in today

    int newStreak = 1;
    if (state.lastLoginDate == _yesterday) {
      newStreak = state.loginStreak + 1;
    }

    // Daily login: 3 coins
    _addTransaction(
      type: CoinTransactionType.loginBonus,
      amount: 3,
      description: 'Daily login bonus',
    );

    // Streak bonuses
    if (newStreak == 7) {
      _addTransaction(
        type: CoinTransactionType.streakBonus,
        amount: 50,
        description: '🔥 7-day streak bonus!',
      );
    } else if (newStreak == 30) {
      _addTransaction(
        type: CoinTransactionType.streakBonus,
        amount: 200,
        description: '🏆 30-day streak bonus!',
      );
    } else if (newStreak > 0 && newStreak % 30 == 0) {
      _addTransaction(
        type: CoinTransactionType.streakBonus,
        amount: 200,
        description: '🏆 ${newStreak}-day streak bonus!',
      );
    }

    state = state.copyWith(
      loginStreak: newStreak,
      lastLoginDate: _today,
    );
    _save();
  }

  /// Expire timed items (like premium)
  void _expireTimedItems() {
    final now = DateTime.now();
    final updated = Map<String, DateTime>.from(state.timedItems);
    bool changed = false;
    for (final entry in state.timedItems.entries) {
      if (now.isAfter(entry.value)) {
        updated.remove(entry.key);
        changed = true;
      }
    }
    if (changed) {
      state = state.copyWith(timedItems: updated);
      _save();
    }
  }

  /// Add a transaction
  void _addTransaction({
    required CoinTransactionType type,
    required int amount,
    required String description,
    String? itemId,
  }) {
    final tx = CoinTransaction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      type: type,
      amount: amount,
      description: description,
      timestamp: DateTime.now(),
      itemId: itemId,
    );

    final newHistory = [tx, ...state.history].take(50).toList();

    if (amount > 0) {
      state = state.copyWith(
        balance: state.balance + amount,
        totalEarned: state.totalEarned + amount,
        history: newHistory,
      );
    } else {
      state = state.copyWith(
        balance: state.balance + amount, // amount is negative
        totalSpent: state.totalSpent + amount.abs(),
        history: newHistory,
      );
    }
  }

  // ─── EARNING METHODS ────────────────────────────────────────

  /// Award coins for completing all 5 prayers (call once per day)
  Future<void> awardDailyPrayer() async {
    if (state.lastDailyPrayerDate == _today) return;
    _addTransaction(
      type: CoinTransactionType.dailyPrayer,
      amount: 25,
      description: 'All 5 prayers completed 🕌',
    );
    state = state.copyWith(lastDailyPrayerDate: _today);
    await _save();
  }

  /// Award coins for completing all 4 daily challenges
  Future<void> awardDailyChallenge() async {
    if (state.lastDailyChallengeDate == _today) return;
    _addTransaction(
      type: CoinTransactionType.dailyChallenge,
      amount: 15,
      description: 'All daily challenges done ✅',
    );
    state = state.copyWith(lastDailyChallengeDate: _today);
    await _save();
  }

  /// Award coins for 100+ dhikr in a day
  Future<void> awardDhikrMilestone() async {
    if (state.lastDhikrMilestoneDate == _today) return;
    _addTransaction(
      type: CoinTransactionType.dhikrMilestone,
      amount: 10,
      description: '100+ dhikr milestone 📿',
    );
    state = state.copyWith(lastDhikrMilestoneDate: _today);
    await _save();
  }

  /// Award coins for Quran reading
  Future<void> awardQuranReading() async {
    if (state.lastQuranReadDate == _today) return;
    _addTransaction(
      type: CoinTransactionType.quranReading,
      amount: 8,
      description: 'Quran reading session 📖',
    );
    state = state.copyWith(lastQuranReadDate: _today);
    await _save();
  }

  /// Award coins for pomodoro completion (max 3/day = 15 coins)
  Future<void> awardPomodoroComplete() async {
    // Reset counter if new day
    int todayCount = state.pomodoroCoinsToday;
    if (state.lastPomodoroDate != _today) {
      todayCount = 0;
    }
    if (todayCount >= 3) return; // Max 3 per day

    _addTransaction(
      type: CoinTransactionType.pomodoroComplete,
      amount: 5,
      description: 'Focus session complete ⏱️',
    );
    state = state.copyWith(
      pomodoroCoinsToday: todayCount + 1,
      lastPomodoroDate: _today,
    );
    await _save();
  }

  /// Add test coins (dev testing only)
  Future<void> addTestCoins(int amount) async {
    _addTransaction(
      type: CoinTransactionType.dailyPrayer,
      amount: amount,
      description: '🧪 Test coins added',
    );
    await _save();
  }

  // ─── SPENDING METHODS ────────────────────────────────────────

  /// Purchase an item from the store
  /// Returns true if purchase succeeded
  Future<bool> purchaseItem(StoreItem item) async {
    // Already owned (non-consumable)
    if (!item.isConsumable && state.ownedItems.contains(item.id)) return false;
    // Not enough coins
    if (state.balance < item.price) return false;

    _addTransaction(
      type: _txTypeForCategory(item.category),
      amount: -item.price,
      description: 'Purchased ${item.name}',
      itemId: item.id,
    );

    final newOwned = Set<String>.from(state.ownedItems)..add(item.id);
    final newTimed = Map<String, DateTime>.from(state.timedItems);

    if (item.isConsumable && item.durationDays != null) {
      // If already has active premium, extend it
      final existingExpiry = newTimed[item.id];
      final baseDate = (existingExpiry != null && existingExpiry.isAfter(DateTime.now()))
          ? existingExpiry
          : DateTime.now();
      newTimed[item.id] = baseDate.add(Duration(days: item.durationDays!));
    }

    state = state.copyWith(
      ownedItems: newOwned,
      timedItems: newTimed,
    );
    await _save();
    return true;
  }

  CoinTransactionType _txTypeForCategory(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.premium: return CoinTransactionType.purchasePremium;
      case StoreCategory.themes: return CoinTransactionType.purchaseTheme;
      case StoreCategory.clockStyles: return CoinTransactionType.purchaseClockStyle;
      case StoreCategory.dhikrSkins: return CoinTransactionType.purchaseDhikrSkin;
      case StoreCategory.soundPacks: return CoinTransactionType.purchaseSoundPack;
      case StoreCategory.widgetStyles: return CoinTransactionType.purchaseWidgetStyle;
      case StoreCategory.titles: return CoinTransactionType.purchaseTitle;
    }
  }

  /// Equip a title
  Future<void> equipTitle(String? titleId) async {
    state = state.copyWith(activeTitle: titleId ?? '');
    await _save();
  }

  /// Equip a dhikr skin
  Future<void> equipDhikrSkin(String? skinId) async {
    state = state.copyWith(activeDhikrSkin: skinId ?? '');
    await _save();
  }

  /// Equip a widget style
  Future<void> equipWidgetStyle(String? styleId) async {
    state = state.copyWith(activeWidgetStyle: styleId ?? '');
    await _save();
  }

  /// Check if user has active premium from coins
  bool get hasCoinPremium {
    final expiry = state.timedItems['premium_30d'];
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// Get premium expiry date
  DateTime? get coinPremiumExpiry => state.timedItems['premium_30d'];
}

// ─── PROVIDERS ──────────────────────────────────────────────────────────────

final sukoonCoinProvider = StateNotifierProvider<SukoonCoinNotifier, SukoonCoinState>(
  (ref) => SukoonCoinNotifier(),
);

/// Quick balance check
final coinBalanceProvider = Provider<int>((ref) {
  return ref.watch(sukoonCoinProvider).balance;
});

/// Check if user has coin-based premium
final hasCoinPremiumProvider = Provider<bool>((ref) {
  return ref.watch(sukoonCoinProvider.notifier).hasCoinPremium;
});
