import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Available theme colors for the app
class AppThemeColor {
  final String name;
  final Color color;
  final Color accentColor;
  final bool isLight;
  const AppThemeColor({
    required this.name,
    required this.color,
    required this.accentColor,
    this.isLight = false,
  });
}

/// ☪️ Sukoon Brand Color Palette - Desert-inspired design system
class SukoonColors {
  // Primary desert tones
  static const Color sandGold = Color(0xFFC2A366);       // Primary brand
  static const Color desertWarm = Color(0xFFD4A96A);      // Warm accent
  static const Color warmBrown = Color(0xFFA67B5B);      // Rich depth
  static const Color sandBeige = Color(0xFFE8D5B7);       // Light sand
  static const Color duneAmber = Color(0xFFDAB87A);       // Golden dune
  static const Color oasisGreen = Color(0xFF7BAE6E);      // Oasis accent
  static const Color desertSunset = Color(0xFFE8915A);    // Sunset glow
  static const Color nightSky = Color(0xFF1A1A2E);        // Desert night
  static const Color starlight = Color(0xFFE6D5A8);       // Star-like warm
  static const Color softCream = Color(0xFFF5ECD7);       // Soft cream
}

/// Predefined theme colors
class ThemeColors {
  // 🌙 Sukoon (Desert) is the DEFAULT brand theme
  static const sukoon = AppThemeColor(
    name: 'Sukoon',
    color: Color(0xFFC2A366),
    accentColor: Color(0xFFD4A96A),
  );

  static const white = AppThemeColor(
    name: 'White',
    color: Colors.white,
    accentColor: Color(0xFFCCCCCC),
  );

  static const blue = AppThemeColor(
    name: 'Blue',
    color: Color(0xFF64B5F6),
    accentColor: Color(0xFF42A5F5),
  );

  static const purple = AppThemeColor(
    name: 'Purple',
    color: Color(0xFF9575CD),
    accentColor: Color(0xFF7E57C2),
  );

  static const green = AppThemeColor(
    name: 'Green',
    color: Color(0xFF81C784),
    accentColor: Color(0xFF66BB6A),
  );

  static const orange = AppThemeColor(
    name: 'Orange',
    color: Color(0xFFFFB74D),
    accentColor: Color(0xFFFFA726),
  );

  static const pink = AppThemeColor(
    name: 'Pink',
    color: Color(0xFFF06292),
    accentColor: Color(0xFFEC407A),
  );

  static const cyan = AppThemeColor(
    name: 'Cyan',
    color: Color(0xFF4DD0E1),
    accentColor: Color(0xFF26C6DA),
  );

  static const amber = AppThemeColor(
    name: 'Amber',
    color: Color(0xFFFFD54F),
    accentColor: Color(0xFFFFCA28),
  );

  // ── Premium colors ──

  static const rose = AppThemeColor(
    name: 'Rose',
    color: Color(0xFFFB7185),
    accentColor: Color(0xFFF43F5E),
  );

  static const lavender = AppThemeColor(
    name: 'Lavender',
    color: Color(0xFFC4B5FD),
    accentColor: Color(0xFFA78BFA),
  );

  static const teal = AppThemeColor(
    name: 'Teal',
    color: Color(0xFF2DD4BF),
    accentColor: Color(0xFF14B8A6),
  );

  static const coral = AppThemeColor(
    name: 'Coral',
    color: Color(0xFFFB923C),
    accentColor: Color(0xFFF97316),
  );

  static const skyBlue = AppThemeColor(
    name: 'Sky Blue',
    color: Color(0xFF38BDF8),
    accentColor: Color(0xFF0EA5E9),
  );

  static const emerald = AppThemeColor(
    name: 'Emerald',
    color: Color(0xFF34D399),
    accentColor: Color(0xFF10B981),
  );

  static const crimson = AppThemeColor(
    name: 'Crimson',
    color: Color(0xFFEF4444),
    accentColor: Color(0xFFDC2626),
  );

  static const mint = AppThemeColor(
    name: 'Mint',
    color: Color(0xFF6EE7B7),
    accentColor: Color(0xFF34D399),
  );

  static const indigo = AppThemeColor(
    name: 'Indigo',
    color: Color(0xFF818CF8),
    accentColor: Color(0xFF6366F1),
  );

  static const peach = AppThemeColor(
    name: 'Peach',
    color: Color(0xFFFDA4AF),
    accentColor: Color(0xFFFB7185),
  );

  static const slate = AppThemeColor(
    name: 'Slate',
    color: Color(0xFF94A3B8),
    accentColor: Color(0xFF64748B),
  );

  static const gold = AppThemeColor(
    name: 'Gold',
    color: Color(0xFFFBBF24),
    accentColor: Color(0xFFF59E0B),
  );

  static const lilac = AppThemeColor(
    name: 'Lilac',
    color: Color(0xFFD8B4FE),
    accentColor: Color(0xFFC084FC),
  );

  static const aqua = AppThemeColor(
    name: 'Aqua',
    color: Color(0xFF22D3EE),
    accentColor: Color(0xFF06B6D4),
  );

  static const warmRed = AppThemeColor(
    name: 'Warm Red',
    color: Color(0xFFF87171),
    accentColor: Color(0xFFEF4444),
  );

  static const sage = AppThemeColor(
    name: 'Sage',
    color: Color(0xFFA3BE8C),
    accentColor: Color(0xFF8FB573),
  );

  static List<AppThemeColor> get all => [
    sukoon,
    white,
    blue,
    purple,
    green,
    orange,
    pink,
    cyan,
    amber,
    rose,
    lavender,
    teal,
    coral,
    skyBlue,
    emerald,
    crimson,
    mint,
    indigo,
    peach,
    slate,
    gold,
    lilac,
    aqua,
    warmRed,
    sage,
  ];
}

/// Provider for theme color settings
final themeColorProvider =
    StateNotifierProvider<ThemeColorNotifier, AppThemeColor>((ref) {
      return ThemeColorNotifier();
    });

class ThemeColorNotifier extends StateNotifier<AppThemeColor> {
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeColor';
  Box? _box;

  ThemeColorNotifier() : super(ThemeColors.white) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final savedThemeName = _box?.get(_themeKey) as String?;

      if (savedThemeName != null) {
        final theme = ThemeColors.all.firstWhere(
          (t) => t.name == savedThemeName,
          orElse: () => ThemeColors.white,
        );
        state = theme;
      }
    } catch (e) {
      // Handle error, use default theme
      state = ThemeColors.white;
    }
  }

  Future<void> setThemeColor(AppThemeColor theme) async {
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_themeKey, theme.name);
    state = theme;
  }
}
