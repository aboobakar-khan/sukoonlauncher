import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../utils/hive_box_manager.dart';

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier() : super(1.0) {
    _loadFontSize();
  }

  Box? _box;

  Future<void> _loadFontSize() async {
    _box = await HiveBoxManager.get('settings');
    final savedSize = _box!.get('fontSize', defaultValue: 1.0) as double;
    state = savedSize;
  }

  Future<void> setFontSize(double size) async {
    _box ??= await HiveBoxManager.get('settings');
    _box!.put('fontSize', size);
    state = size;
  }
}

final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>(
  (ref) => FontSizeNotifier(),
);

// Font size presets
class FontSizePreset {
  final String name;
  final double scale;

  const FontSizePreset({required this.name, required this.scale});
}

const List<FontSizePreset> fontSizePresets = [
  FontSizePreset(name: 'Small', scale: 0.85),
  FontSizePreset(name: 'Normal (Default)', scale: 1.0),
  FontSizePreset(name: 'Medium', scale: 1.15),
  FontSizePreset(name: 'Large', scale: 1.3),
];
