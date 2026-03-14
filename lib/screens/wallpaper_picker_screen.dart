import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/theme_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/swipe_back_wrapper.dart';
import '../widgets/year_dots_wallpaper.dart';
import 'premium_paywall_screen.dart';

/// Wallpaper Picker Screen
class WallpaperPickerScreen extends ConsumerWidget {
  const WallpaperPickerScreen({super.key});

  // ── Grouped wallpaper sections ──────────────────────────────────────────────
  static const _darkSection = [
    WallpaperType.black,
    WallpaperType.darkGradient,
  ];

  static const _gradientSection = [
    WallpaperType.desertGradient,
    WallpaperType.blueGradient,
    WallpaperType.purpleGradient,
    WallpaperType.redGradient,
    WallpaperType.greenGradient,
    WallpaperType.leafGreenGradient,
    WallpaperType.oceanTealGradient,
    WallpaperType.mintGradient,
    WallpaperType.lavenderGradient,
    WallpaperType.roseGoldGradient,
    WallpaperType.dustyRoseGradient,
    WallpaperType.sunsetPeachGradient,
    WallpaperType.beigeGradient,
  ];

  static const _islamicSection = [
    WallpaperType.islamicNamazMat,
    WallpaperType.islamicInshallah,
    WallpaperType.islamicFlag,
    WallpaperType.islamicQuranDark,
  ];

  static const _customSection = [
    WallpaperType.customImage,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWallpaper = ref.watch(wallpaperProvider);
    final isPremium = ref.watch(premiumProvider).isPremium;
    // NOTE: wallpaper picker doesn't watch themeColorProvider directly
    // but we need isLight for the UI chrome (bg, headers, text)
    // Importing theme_provider to read isLight
    final themeColor = ref.watch(themeColorProvider);
    final isLight = themeColor.isLight;
    final bgColor = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;

    return SwipeBackWrapper(
      child: Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(context, primaryText: primaryText)),

            // Dark & Minimal
            _buildSectionHeader('DARK & MINIMAL', primaryText: primaryText),
            _buildWallpaperGrid(context, ref, _darkSection, currentWallpaper, isPremium, primaryText: primaryText),

            // Color Gradients
            _buildSectionHeader('COLOR GRADIENTS', primaryText: primaryText),
            _buildWallpaperGrid(context, ref, _gradientSection, currentWallpaper, isPremium, primaryText: primaryText),

            // Islamic
            _buildSectionHeader('ISLAMIC  ·  PRO', primaryText: primaryText),
            _buildWallpaperGrid(context, ref, _islamicSection, currentWallpaper, isPremium, primaryText: primaryText),

            // Custom
            _buildSectionHeader('CUSTOM', primaryText: primaryText),
            _buildWallpaperGrid(context, ref, _customSection, currentWallpaper, isPremium, primaryText: primaryText),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String label, {required Color primaryText}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            color: primaryText.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  SliverPadding _buildWallpaperGrid(
    BuildContext context,
    WidgetRef ref,
    List<WallpaperType> wallpapers,
    WallpaperType currentWallpaper,
    bool isPremium, {
    required Color primaryText,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final wallpaper = wallpapers[index];
            final isSelected = wallpaper == currentWallpaper;
            final isLocked = premiumWallpapers.contains(wallpaper) && !isPremium;
            return _buildWallpaperCard(context, ref, wallpaper, isSelected, isLocked, primaryText: primaryText);
          },
          childCount: wallpapers.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required Color primaryText}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back,
              color: primaryText.withValues(alpha: 0.7),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'WALLPAPER',
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 4,
              fontWeight: FontWeight.w300,
              color: primaryText.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallpaperCard(
    BuildContext context,
    WidgetRef ref,
    WallpaperType wallpaper,
    bool isSelected,
    bool isLocked, {
    required Color primaryText,
  }) {
    final assetPath = wallpaperAssetPath(wallpaper);
    return GestureDetector(
      onTap: () async {
        if (isLocked) {
          showPremiumPaywall(context);
          return;
        }
        if (wallpaper == WallpaperType.customImage) {
          await _pickImageFromDevice(context, ref);
        } else {
          ref.read(wallpaperProvider.notifier).setWallpaper(wallpaper);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryText.withValues(alpha: 0.6)
                : primaryText.withValues(alpha: 0.15),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallpaper preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: (assetPath == null && wallpaper != WallpaperType.yearDots)
                      ? _getWallpaperGradient(wallpaper)
                      : null,
                  color: (wallpaper == WallpaperType.customImage || assetPath != null || wallpaper == WallpaperType.yearDots)
                      ? Colors.black
                      : null,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (wallpaper == WallpaperType.yearDots)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: const YearDotsPreview(),
                      )
                    else if (assetPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (wallpaper == WallpaperType.customImage)
                      _buildCustomImagePreview(ref),
                    // Lock overlay for premium
                    if (isLocked)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC2A366).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFC2A366).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  color: const Color(0xFFC2A366),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: const Color(0xFFC2A366),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Wallpaper info
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          wallpaper.name,
                          style: TextStyle(
                            color: primaryText.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: primaryText.withValues(alpha: 0.8),
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wallpaper.description,
                    style: TextStyle(
                      color: primaryText.withValues(alpha: 0.4),
                      fontSize: 11,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _getWallpaperGradient(WallpaperType wallpaper) {
    switch (wallpaper) {
      case WallpaperType.black:
        return const LinearGradient(colors: [Colors.black, Colors.black]);
      case WallpaperType.darkGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0a0a0a),
            const Color(0xFF1a1a1a),
            Colors.black,
          ],
        );
      case WallpaperType.desertGradient:
        // 🌙 Desert gradient preview
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A150D),
            const Color(0xFF2A1F12),
            Colors.black,
          ],
        );
      case WallpaperType.blueGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0d1b2a),
            const Color(0xFF1b263b),
            Colors.black,
          ],
        );
      case WallpaperType.purpleGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a0a2e),
            const Color(0xFF16213e),
            Colors.black,
          ],
        );
      case WallpaperType.redGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2d0a0a),
            const Color(0xFF1a0a0a),
            Colors.black,
          ],
        );
      case WallpaperType.greenGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0a2d0a),
            const Color(0xFF0a1a0a),
            Colors.black,
          ],
        );
      case WallpaperType.customImage:
        return const LinearGradient(colors: [Colors.black, Colors.black]);
      case WallpaperType.islamicNamazMat:
      case WallpaperType.islamicInshallah:
      case WallpaperType.islamicFlag:
      case WallpaperType.islamicQuranDark:
      case WallpaperType.yearDots:
        return const LinearGradient(colors: [Colors.black, Colors.black]);

      // ── Aesthetic light-toned gradients ──
      case WallpaperType.leafGreenGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1F0D),
            const Color(0xFF1A3A1A),
            const Color(0xFF071007),
          ],
        );
      case WallpaperType.beigeGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F1A12),
            const Color(0xFF302818),
            const Color(0xFF0D0B07),
          ],
        );
      case WallpaperType.roseGoldGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A1A1A),
            const Color(0xFF3A2222),
            const Color(0xFF0D0808),
          ],
        );
      case WallpaperType.lavenderGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A142A),
            const Color(0xFF251C3A),
            const Color(0xFF0A0810),
          ],
        );
      case WallpaperType.oceanTealGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A1F1F),
            const Color(0xFF0F2D2A),
            const Color(0xFF050E0E),
          ],
        );
      case WallpaperType.sunsetPeachGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A1810),
            const Color(0xFF3A2215),
            const Color(0xFF0D0905),
          ],
        );
      case WallpaperType.mintGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D2018),
            const Color(0xFF143025),
            const Color(0xFF060E0A),
          ],
        );
      case WallpaperType.dustyRoseGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF221418),
            const Color(0xFF301C22),
            const Color(0xFF0D080A),
          ],
        );
    }
  }

  Widget _buildCustomImagePreview(WidgetRef ref) {
    final imagePath = ref.read(wallpaperProvider.notifier).customImagePath;

    if (imagePath != null && File(imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(File(imagePath), fit: BoxFit.cover),
      );
    }

    return Center(
      child: Icon(
        Icons.add_photo_alternate_outlined,
        color: Colors.white.withValues(alpha: 0.5),
        size: 48,
      ),
    );
  }

  Future<void> _pickImageFromDevice(BuildContext context, WidgetRef ref) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        await ref
            .read(wallpaperProvider.notifier)
            .setWallpaper(WallpaperType.customImage, imagePath: image.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red.withValues(alpha: 0.8),
          ),
        );
      }
    }
  }
}
