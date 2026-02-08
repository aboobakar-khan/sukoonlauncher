import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font category for grouping in the picker
enum FontCategory { sansSerif, serif, display }

/// Available font styles for the app — each entry is a heading + body pair
class AppFont {
  final String name;
  final String? fontFamily;        // Body / default font
  final String? headingFontFamily; // Heading font (falls back to fontFamily)
  final FontCategory category;

  const AppFont({
    required this.name,
    this.fontFamily,
    this.headingFontFamily,
    this.category = FontCategory.sansSerif,
  });

  /// Returns the heading font, falling back to the body font
  String? get headingFamily => headingFontFamily ?? fontFamily;
}

/// Predefined font styles — organized as curated pairs
class AppFonts {
  // ─── Sans-Serif ───────────────────────────────────
  static const system = AppFont(
    name: 'System Default',
    fontFamily: null,
    category: FontCategory.sansSerif,
  );

  static final inter = AppFont(
    name: 'Inter',
    fontFamily: GoogleFonts.inter().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final roboto = AppFont(
    name: 'Roboto',
    fontFamily: GoogleFonts.roboto().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final openSans = AppFont(
    name: 'Open Sans',
    fontFamily: GoogleFonts.openSans().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final lato = AppFont(
    name: 'Lato',
    fontFamily: GoogleFonts.lato().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final poppins = AppFont(
    name: 'Poppins',
    fontFamily: GoogleFonts.poppins().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final montserrat = AppFont(
    name: 'Montserrat',
    fontFamily: GoogleFonts.montserrat().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final raleway = AppFont(
    name: 'Raleway',
    fontFamily: GoogleFonts.raleway().fontFamily,
    category: FontCategory.sansSerif,
  );

  static final nunito = AppFont(
    name: 'Nunito',
    fontFamily: GoogleFonts.nunito().fontFamily,
    category: FontCategory.sansSerif,
  );

  // ─── Serif ────────────────────────────────────────
  static final merriweather = AppFont(
    name: 'Merriweather',
    fontFamily: GoogleFonts.merriweather().fontFamily,
    category: FontCategory.serif,
  );

  static final sourceSerif = AppFont(
    name: 'Source Serif',
    fontFamily: GoogleFonts.sourceSerif4().fontFamily,
    category: FontCategory.serif,
  );

  static final libreBaskerville = AppFont(
    name: 'Libre Baskerville',
    fontFamily: GoogleFonts.libreBaskerville().fontFamily,
    category: FontCategory.serif,
  );

  static final lora = AppFont(
    name: 'Lora',
    fontFamily: GoogleFonts.lora().fontFamily,
    category: FontCategory.serif,
  );

  static final ebGaramond = AppFont(
    name: 'EB Garamond',
    fontFamily: GoogleFonts.ebGaramond().fontFamily,
    category: FontCategory.serif,
  );

  static final crimsonText = AppFont(
    name: 'Crimson Text',
    fontFamily: GoogleFonts.crimsonText().fontFamily,
    category: FontCategory.serif,
  );

  // ─── Display Pairs (heading + body) ───────────────
  static final playfairInter = AppFont(
    name: 'Playfair + Inter',
    fontFamily: GoogleFonts.inter().fontFamily,
    headingFontFamily: GoogleFonts.playfairDisplay().fontFamily,
    category: FontCategory.display,
  );

  static final montserratMerriweather = AppFont(
    name: 'Montserrat + Merriweather',
    fontFamily: GoogleFonts.merriweather().fontFamily,
    headingFontFamily: GoogleFonts.montserrat().fontFamily,
    category: FontCategory.display,
  );

  static final oswaldSourceSerif = AppFont(
    name: 'Oswald + Source Serif',
    fontFamily: GoogleFonts.sourceSerif4().fontFamily,
    headingFontFamily: GoogleFonts.oswald().fontFamily,
    category: FontCategory.display,
  );

  static final ralewayLora = AppFont(
    name: 'Raleway + Lora',
    fontFamily: GoogleFonts.lora().fontFamily,
    headingFontFamily: GoogleFonts.raleway().fontFamily,
    category: FontCategory.display,
  );

  static List<AppFont> get all => [
    // Sans-Serif
    system,
    inter,
    roboto,
    openSans,
    lato,
    poppins,
    montserrat,
    raleway,
    nunito,
    // Serif
    merriweather,
    sourceSerif,
    libreBaskerville,
    lora,
    ebGaramond,
    crimsonText,
    // Display Pairs
    playfairInter,
    montserratMerriweather,
    oswaldSourceSerif,
    ralewayLora,
  ];

  /// Fonts grouped by category
  static Map<FontCategory, List<AppFont>> get grouped {
    final map = <FontCategory, List<AppFont>>{};
    for (final font in all) {
      map.putIfAbsent(font.category, () => []).add(font);
    }
    return map;
  }

  /// Category display name
  static String categoryName(FontCategory cat) {
    switch (cat) {
      case FontCategory.sansSerif:
        return 'Sans-Serif';
      case FontCategory.serif:
        return 'Serif';
      case FontCategory.display:
        return 'Display Pairs';
    }
  }
}

/// Provider for font settings
final fontProvider = StateNotifierProvider<FontNotifier, AppFont>((ref) {
  return FontNotifier();
});

class FontNotifier extends StateNotifier<AppFont> {
  static const String _boxName = 'settings';
  static const String _fontKey = 'appFont';
  Box? _box;

  FontNotifier() : super(AppFonts.system) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await Hive.openBox(_boxName);
      final savedFontName = _box?.get(_fontKey) as String?;

      if (savedFontName != null) {
        final font = AppFonts.all.firstWhere(
          (f) => f.name == savedFontName,
          orElse: () => AppFonts.system,
        );
        state = font;
      }
    } catch (e) {
      // Handle error, use default font
      state = AppFonts.system;
    }
  }

  Future<void> setFont(AppFont font) async {
    _box ??= await Hive.openBox(_boxName);
    await _box?.put(_fontKey, font.name);
    state = font;
  }
}
