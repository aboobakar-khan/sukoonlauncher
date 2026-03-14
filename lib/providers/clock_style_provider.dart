import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Available clock styles for the app
enum ClockStyle {
  digital,
  analog,
  minimalist,
  bold,
  compact,
  modern,
  retro,
  elegant,
  binary,
  progress,
  vertical,
  word,
  dotMatrix,
  zen,
  typewriter,
  arc,
}

extension ClockStyleExtension on ClockStyle {
  String get name {
    switch (this) {
      case ClockStyle.digital:
        return 'Digital';
      case ClockStyle.analog:
        return 'Analog';
      case ClockStyle.minimalist:
        return 'Minimalist';
      case ClockStyle.bold:
        return 'Bold';
      case ClockStyle.compact:
        return 'Compact';
      case ClockStyle.modern:
        return 'Modern';
      case ClockStyle.retro:
        return 'Retro';
      case ClockStyle.elegant:
        return 'Elegant';
      case ClockStyle.binary:
        return 'Binary';
      case ClockStyle.progress:
        return 'Progress';
      case ClockStyle.vertical:
        return 'Vertical';
      case ClockStyle.word:
        return 'Word';
      case ClockStyle.dotMatrix:
        return 'Dot Matrix';
      case ClockStyle.zen:
        return 'Zen';
      case ClockStyle.typewriter:
        return 'Typewriter';
      case ClockStyle.arc:
        return 'Arc';
    }
  }

  String get description {
    switch (this) {
      case ClockStyle.digital:
        return 'Classic digital clock';
      case ClockStyle.analog:
        return 'Traditional analog clock';
      case ClockStyle.minimalist:
        return 'Simple and clean';
      case ClockStyle.bold:
        return 'Large and prominent';
      case ClockStyle.compact:
        return 'Space-saving layout';
      case ClockStyle.modern:
        return 'Sleek contemporary style';
      case ClockStyle.retro:
        return 'Vintage flip-clock style';
      case ClockStyle.elegant:
        return 'Refined and sophisticated';
      case ClockStyle.binary:
        return 'Geek mode - binary time';
      case ClockStyle.progress:
        return 'Circular arc fills with time';
      case ClockStyle.vertical:
        return 'Stacked digits, editorial feel';
      case ClockStyle.word:
        return 'Time spoken in words';
      case ClockStyle.dotMatrix:
        return 'LED dot-grid display';
      case ClockStyle.zen:
        return 'Breathing minimal presence';
      case ClockStyle.typewriter:
        return 'Monospaced typed-out look';
      case ClockStyle.arc:
        return 'Time curved along an arc';
    }
  }
}

/// Provider for clock style settings
final clockStyleProvider =
    StateNotifierProvider<ClockStyleNotifier, ClockStyle>((ref) {
      return ClockStyleNotifier();
    });

class ClockStyleNotifier extends StateNotifier<ClockStyle> {
  static const String _boxName = 'settings';
  static const String _clockKey = 'clockStyle';
  Box? _box;

  ClockStyleNotifier() : super(ClockStyle.minimalist) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final savedStyle = _box?.get(_clockKey) as String?;

      if (savedStyle != null) {
        final style = ClockStyle.values.firstWhere(
          (s) => s.name == savedStyle,
          orElse: () => ClockStyle.minimalist,
        );
        state = style;
      }
    } catch (e) {
      // Handle error, use default style
      state = ClockStyle.minimalist;
    }
  }

  Future<void> setClockStyle(ClockStyle style) async {
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_clockKey, style.name);
    state = style;
  }
}
