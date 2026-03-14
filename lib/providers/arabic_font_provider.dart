import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/hive_box_manager.dart';

/// Available Arabic font styles for Quran
class ArabicFont {
  final String name;
  final String? fontFamily;

  const ArabicFont({required this.name, this.fontFamily});
}

/// Predefined Arabic font styles optimized for Quran reading
class ArabicFonts {
  static const system = ArabicFont(name: 'System Default', fontFamily: null);

  static final amiri = ArabicFont(
    name: 'Amiri',
    fontFamily: GoogleFonts.amiri().fontFamily,
  );

  static final scheherazadeNew = ArabicFont(
    name: 'Scheherazade New',
    fontFamily: GoogleFonts.scheherazadeNew().fontFamily,
  );

  static final cairo = ArabicFont(
    name: 'Cairo',
    fontFamily: GoogleFonts.cairo().fontFamily,
  );

  static final lateef = ArabicFont(
    name: 'Lateef',
    fontFamily: GoogleFonts.lateef().fontFamily,
  );

  static final elMessiri = ArabicFont(
    name: 'El Messiri',
    fontFamily: GoogleFonts.elMessiri().fontFamily,
  );

  static final tajawal = ArabicFont(
    name: 'Tajawal',
    fontFamily: GoogleFonts.tajawal().fontFamily,
  );

  static final arefRuqaa = ArabicFont(
    name: 'Aref Ruqaa',
    fontFamily: GoogleFonts.arefRuqaa().fontFamily,
  );

  static final rakkas = ArabicFont(
    name: 'Rakkas',
    fontFamily: GoogleFonts.rakkas().fontFamily,
  );

  static final marhey = ArabicFont(
    name: 'Marhey',
    fontFamily: GoogleFonts.marhey().fontFamily,
  );

  static final reem = ArabicFont(
    name: 'Reem Kufi',
    fontFamily: GoogleFonts.reemKufi().fontFamily,
  );

  /// All available Arabic fonts
  static final all = [
    system,
    amiri,
    scheherazadeNew,
    cairo,
    lateef,
    elMessiri,
    tajawal,
    arefRuqaa,
    rakkas,
    marhey,
    reem,
  ];
}

/// Provider for managing the selected Arabic font
class ArabicFontNotifier extends StateNotifier<ArabicFont> {
  ArabicFontNotifier() : super(ArabicFonts.amiri) {
    _loadFont();
  }

  Box? _box;

  Future<void> _loadFont() async {
    _box ??= await HiveBoxManager.get('arabic_font');
    final savedFont = _box!.get('font_name');

    if (savedFont != null) {
      // Find the matching font
      final font = ArabicFonts.all.firstWhere(
        (f) => f.name == savedFont,
        orElse: () => ArabicFonts.amiri,
      );
      state = font;
    }
  }

  Future<void> setFont(ArabicFont font) async {
    _box ??= await HiveBoxManager.get('arabic_font');
    await _box!.put('font_name', font.name);
    state = font;
  }
}

final arabicFontProvider =
    StateNotifierProvider<ArabicFontNotifier, ArabicFont>(
      (ref) => ArabicFontNotifier(),
    );
