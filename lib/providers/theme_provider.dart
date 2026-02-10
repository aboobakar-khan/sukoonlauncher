import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Available theme colors for the app
class AppThemeColor {
  final String name;
  final Color color;
  final Color accentColor;

  const AppThemeColor({
    required this.name,
    required this.color,
    required this.accentColor,
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
    accentColor: Color(0xFFE0E0E0),
  );

  static const blue = AppThemeColor(
    name: 'Blue',
    color: Color(0xFF64B5F6),
    accentColor: Color(0xFF42A5F5),
  );

  static const purple = AppThemeColor(
    name: 'Purple',
    color: Color(0xFFBA68C8),
    accentColor: Color(0xFFAB47BC),
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

  ThemeColorNotifier() : super(ThemeColors.sukoon) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await Hive.openBox(_boxName);
      final savedThemeName = _box?.get(_themeKey) as String?;

      if (savedThemeName != null) {
        final theme = ThemeColors.all.firstWhere(
          (t) => t.name == savedThemeName,
          orElse: () => ThemeColors.sukoon,
        );
        state = theme;
      }
    } catch (e) {
      // Handle error, use default theme
      state = ThemeColors.sukoon;
    }
  }

  Future<void> setThemeColor(AppThemeColor theme) async {
    _box ??= await Hive.openBox(_boxName);
    await _box?.put(_themeKey, theme.name);
    state = theme;
  }
}
