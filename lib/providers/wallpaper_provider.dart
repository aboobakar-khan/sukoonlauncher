import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

enum WallpaperType {
  black,
  darkGradient,
  desertGradient,
  blueGradient,
  purpleGradient,
  redGradient,
  greenGradient,
  customImage,
}

final wallpaperProvider =
    StateNotifierProvider<WallpaperNotifier, WallpaperType>(
      (ref) => WallpaperNotifier(),
    );

class WallpaperNotifier extends StateNotifier<WallpaperType> {
  WallpaperNotifier() : super(WallpaperType.black) {
    _loadFromHive();
  }

  static const _boxName = 'wallpaperBox';
  static const _wallpaperKey = 'wallpaperType';
  static const _imagePathKey = 'customImagePath';

  String? customImagePath;
  late final Box _box = Hive.box(_boxName);

  // 🔹 Load saved wallpaper
  void _loadFromHive() {
    final int? index = _box.get(_wallpaperKey);
    final String? path = _box.get(_imagePathKey);

    if (path != null && File(path).existsSync()) {
      customImagePath = path;
    }

    if (index != null && index < WallpaperType.values.length) {
      state = WallpaperType.values[index];
    }
  }

  // 🔹 Save wallpaper
  Future<void> setWallpaper(WallpaperType type, {String? imagePath}) async {
    state = type;
    await _box.put(_wallpaperKey, type.index);

    if (imagePath != null) {
      customImagePath = imagePath;
      await _box.put(_imagePathKey, imagePath);
    }
  }

  // 🔹 Reset wallpaper
  Future<void> reset() async {
    customImagePath = null;
    await _box.delete(_imagePathKey);
    await _box.put(_wallpaperKey, WallpaperType.black.index);
    state = WallpaperType.black;
  }
}

extension WallpaperTypeUI on WallpaperType {
  String get description {
    switch (this) {
      case WallpaperType.black:
        return 'Pure black wallpaper';
      case WallpaperType.darkGradient:
        return 'Dark animated gradient';
      case WallpaperType.desertGradient:
        return '🌙 Desert gradient';
      case WallpaperType.blueGradient:
        return 'Blue animated gradient';
      case WallpaperType.purpleGradient:
        return 'Purple animated gradient';
      case WallpaperType.redGradient:
        return 'Red animated gradient';
      case WallpaperType.greenGradient:
        return 'Green animated gradient';
      case WallpaperType.customImage:
        return 'Pick image from gallery';
    }
  }
}
