import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/hive_box_manager.dart';

/// Clock opacity levels
enum ClockOpacity {
  low,
  medium,
  high,
  veryHigh,
  ultraHigh;

  String get name {
    switch (this) {
      case ClockOpacity.low:
        return 'Low (40%)';
      case ClockOpacity.medium:
        return 'Medium (70%)';
      case ClockOpacity.high:
        return 'High (90%)';
      case ClockOpacity.veryHigh:
        return 'Very High (110%)';
      case ClockOpacity.ultraHigh:
        return 'Ultra High (130%)';
    }
  }

  double get value {
    switch (this) {
      case ClockOpacity.low:
        return 0.4;
      case ClockOpacity.medium:
        return 0.7;
      case ClockOpacity.high:
        return 0.9;
      case ClockOpacity.veryHigh:
        return 1.1;
      case ClockOpacity.ultraHigh:
        return 1.3;
    }
  }
}

class ClockOpacityNotifier extends StateNotifier<ClockOpacity> {
  ClockOpacityNotifier() : super(ClockOpacity.high) {
    _loadOpacity();
  }

  Future<void> _loadOpacity() async {
    try {
      final box = await HiveBoxManager.get('settings');
      final savedOpacity = box.get('clockOpacity', defaultValue: 'high');
      if (savedOpacity != null) {
        final opacity = ClockOpacity.values.firstWhere(
          (o) => o.toString().split('.').last == savedOpacity.toString(),
          orElse: () => ClockOpacity.high,
        );
        state = opacity;
      }
    } catch (e) {
      state = ClockOpacity.high;
    }
  }

  Future<void> setOpacity(ClockOpacity opacity) async {
    try {
      final box = await HiveBoxManager.get('settings');
      await box.put('clockOpacity', opacity.toString().split('.').last);
      state = opacity;
    } catch (e) {
      // Handle error silently
    }
  }
}

final clockOpacityProvider =
    StateNotifierProvider<ClockOpacityNotifier, ClockOpacity>(
      (ref) => ClockOpacityNotifier(),
    );
