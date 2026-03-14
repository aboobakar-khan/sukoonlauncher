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
  // Premium Islamic wallpapers
  islamicNamazMat,
  islamicInshallah,
  islamicFlag,
  islamicQuranDark,
  // Static wallpapers
  yearDots,
  // Aesthetic light-toned gradients
  leafGreenGradient,
  beigeGradient,
  roseGoldGradient,
  lavenderGradient,
  oceanTealGradient,
  sunsetPeachGradient,
  mintGradient,
  dustyRoseGradient,
}

/// Which wallpapers are premium (require unlock)
const premiumWallpapers = {
  WallpaperType.islamicNamazMat,
  WallpaperType.islamicInshallah,
  WallpaperType.islamicFlag,
  WallpaperType.islamicQuranDark,
};

/// Asset path for premium wallpapers
String? wallpaperAssetPath(WallpaperType type) {
  switch (type) {
    case WallpaperType.islamicNamazMat:
      return 'assets/wallpapers/namazmat.jpg';
    case WallpaperType.islamicInshallah:
      return 'assets/wallpapers/inshallah.jpg';
    case WallpaperType.islamicFlag:
      return 'assets/wallpapers/islamic_flag.jpg';
    case WallpaperType.islamicQuranDark:
      return 'assets/wallpapers/quran_dark.jpg';
    default:
      return null;
  }
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
      case WallpaperType.islamicNamazMat:
        return '🕌 Premium · Namaz Mat';
      case WallpaperType.islamicInshallah:
        return '🤲 Premium · Inshallah';
      case WallpaperType.islamicFlag:
        return '☪ Premium · Islamic Flag';
      case WallpaperType.islamicQuranDark:
        return '📖 Premium · Quran Dark';
      case WallpaperType.yearDots:
        return '365-dot year progress grid';
      case WallpaperType.leafGreenGradient:
        return '🌿 Fresh leaf green';
      case WallpaperType.beigeGradient:
        return '🏜️ Warm beige sand';
      case WallpaperType.roseGoldGradient:
        return '✨ Rose gold shimmer';
      case WallpaperType.lavenderGradient:
        return '💜 Soft lavender mist';
      case WallpaperType.oceanTealGradient:
        return '🌊 Ocean teal breeze';
      case WallpaperType.sunsetPeachGradient:
        return '🌅 Sunset peach glow';
      case WallpaperType.mintGradient:
        return '🍃 Cool mint fresh';
      case WallpaperType.dustyRoseGradient:
        return '🌸 Dusty rose bloom';
    }
  }
}
