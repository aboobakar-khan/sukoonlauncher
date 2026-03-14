import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';

/// Available time formats
enum TimeFormat { hour24, hour12 }

extension TimeFormatExtension on TimeFormat {
  String get name {
    switch (this) {
      case TimeFormat.hour24:
        return '24-Hour';
      case TimeFormat.hour12:
        return '12-Hour (AM/PM)';
    }
  }

  String get description {
    switch (this) {
      case TimeFormat.hour24:
        return 'Military time (23:59)';
      case TimeFormat.hour12:
        return 'Standard time (11:59 PM)';
    }
  }
}

/// Provider for time format settings
final timeFormatProvider =
    StateNotifierProvider<TimeFormatNotifier, TimeFormat>((ref) {
      return TimeFormatNotifier();
    });

class TimeFormatNotifier extends StateNotifier<TimeFormat> {
  static const String _boxName = 'settings';
  static const String _formatKey = 'timeFormat';
  Box? _box;

  TimeFormatNotifier() : super(TimeFormat.hour24) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get(_boxName);
      final savedFormat = _box?.get(_formatKey) as String?;

      if (savedFormat != null) {
        final format = TimeFormat.values.firstWhere(
          (f) => f.name == savedFormat,
          orElse: () => TimeFormat.hour24,
        );
        state = format;
      }
    } catch (e) {
      // Handle error, use default format
      state = TimeFormat.hour24;
    }
  }

  Future<void> setTimeFormat(TimeFormat format) async {
    _box ??= await HiveBoxManager.get(_boxName);
    await _box?.put(_formatKey, format.name);
    state = format;
  }
}
