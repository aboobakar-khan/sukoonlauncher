import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/font_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/swipe_back_wrapper.dart';

/// Font Picker Screen — categorized with pair previews, theme-aware accent
class FontPickerScreen extends ConsumerWidget {
  const FontPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFont = ref.watch(fontProvider);
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final isLight = themeColor.isLight;
    final bgColor = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;
    final grouped = AppFonts.grouped;
    final categories = [FontCategory.sansSerif, FontCategory.serif, FontCategory.display];

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isLight: isLight, primaryText: primaryText),

            // Font list grouped by category
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  for (final category in categories) ...[
                    if (grouped[category] != null) ...[
                      _buildCategoryHeader(AppFonts.categoryName(category), accent),
                      const SizedBox(height: 10),
                      for (final font in grouped[category]!)
                        _buildFontOption(context, ref, font, font.name == currentFont.name, accent, isLight: isLight, primaryText: primaryText),
                      const SizedBox(height: 20),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isLight, required Color primaryText}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryText.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: primaryText.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Font Style',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose your typography',
                style: TextStyle(
                  fontSize: 12,
                  color: primaryText.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: accent.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontOption(
    BuildContext context,
    WidgetRef ref,
    AppFont font,
    bool isSelected,
    Color accent, {
    required bool isLight,
    required Color primaryText,
  }) {
    final bool isPair = font.headingFontFamily != null && font.headingFontFamily != font.fontFamily;
    final itemBg = isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03);
    final itemBorder = isLight ? Colors.black.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.04);

    return GestureDetector(
      onTap: () {
        ref.read(fontProvider.notifier).setFont(font);
        Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.06)
              : itemBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.3)
                : itemBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Font name
                  Text(
                    font.name,
                    style: TextStyle(
                      fontFamily: font.headingFamily,
                      color: isSelected ? primaryText : primaryText.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Preview — heading style
                  if (isPair) ...[
                    Text(
                      'Heading Preview',
                      style: TextStyle(
                        fontFamily: font.headingFamily,
                        color: primaryText.withValues(alpha: 0.6),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Preview — body style
                  Text(
                    'The quick brown fox jumps over the lazy dog',
                    style: TextStyle(
                      fontFamily: font.fontFamily,
                      color: primaryText.withValues(alpha: 0.35),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  // Show pair labels
                  if (isPair) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPairChip('H', font.headingFontFamily, accent, primaryText: primaryText),
                        const SizedBox(width: 8),
                        _buildPairChip('B', font.fontFamily, accent, primaryText: primaryText),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: accent,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairChip(String label, String? fontFamily, Color accent, {required Color primaryText}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            fontFamily ?? 'System',
            style: TextStyle(
              color: primaryText.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
