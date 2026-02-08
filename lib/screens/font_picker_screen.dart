import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/font_provider.dart';

/// Font Picker Screen — categorized with pair previews
class FontPickerScreen extends ConsumerWidget {
  const FontPickerScreen({super.key});

  static const _gold = Color(0xFFC2A366);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFont = ref.watch(fontProvider);
    final grouped = AppFonts.grouped;
    final categories = [FontCategory.sansSerif, FontCategory.serif, FontCategory.display];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Font list grouped by category
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  for (final category in categories) ...[
                    if (grouped[category] != null) ...[
                      _buildCategoryHeader(AppFonts.categoryName(category)),
                      const SizedBox(height: 10),
                      for (final font in grouped[category]!)
                        _buildFontOption(context, ref, font, font.name == currentFont.name),
                      const SizedBox(height: 20),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Font Style',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose your typography',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.5),
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
              color: _gold.withValues(alpha: 0.6),
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
  ) {
    final bool isPair = font.headingFontFamily != null && font.headingFontFamily != font.fontFamily;

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
              ? _gold.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _gold.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.04),
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
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
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
                        color: Colors.white.withValues(alpha: 0.6),
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
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  // Show pair labels
                  if (isPair) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPairChip('H', font.headingFontFamily),
                        const SizedBox(width: 8),
                        _buildPairChip('B', font.fontFamily),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: _gold,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairChip(String label, String? fontFamily) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _gold.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            fontFamily ?? 'System',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
