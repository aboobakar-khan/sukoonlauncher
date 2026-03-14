import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallpaper_provider.dart';

/// Falls back to gradient animation if Lottie file not found
class AnimatedBackground extends ConsumerStatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  ConsumerState<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends ConsumerState<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _animRunning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    // Don't start animation here — let build() decide based on wallpaper type
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref.watch(wallpaperProvider);
    final assetPath = wallpaperAssetPath(wallpaper);

    // Only run animation for gradient wallpapers — static/image wallpapers
    // don't need GPU frames every 16ms (saves significant battery)
    final needsAnimation = assetPath == null &&
        wallpaper != WallpaperType.black &&
        wallpaper != WallpaperType.customImage;
    if (needsAnimation && !_animRunning) {
      _controller.repeat(reverse: true);
      _animRunning = true;
    } else if (!needsAnimation && _animRunning) {
      _controller.stop();
      _animRunning = false;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: assetPath != null
              ? _buildAssetImageBackground(assetPath)
              : wallpaper == WallpaperType.customImage
                  ? _buildCustomImageBackground()
                  : _buildGradientBackground(),
        ),
        widget.child,
      ],
    );
  }

  /// Premium asset wallpaper (from bundled assets)
  Widget _buildAssetImageBackground(String assetPath) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return _buildGradientBackground();
      },
    );
  }

  Widget _buildGradientBackground() {
    final wallpaper = ref.watch(wallpaperProvider);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(gradient: _getWallpaperGradient(wallpaper)),
        );
      },
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
            Color.lerp(
              const Color(0xFF0a0a0a),
              const Color(0xFF1a1a1a),
              _controller.value,
            )!,
            const Color(0xFF000000),
            Color.lerp(
              const Color(0xFF0f0f0f),
              const Color(0xFF1a1a1a),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.desertGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF1A150D),
              const Color(0xFF2A1F12),
              _controller.value,
            )!,
            const Color(0xFF0A0805),
            Color.lerp(
              const Color(0xFF1F1710),
              const Color(0xFF2A1F12),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.blueGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF0d1b2a),
              const Color(0xFF1b263b),
              _controller.value,
            )!,
            const Color(0xFF000000),
            Color.lerp(
              const Color(0xFF0f1f2f),
              const Color(0xFF1b263b),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.purpleGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF1a0a2e),
              const Color(0xFF16213e),
              _controller.value,
            )!,
            const Color(0xFF000000),
            Color.lerp(
              const Color(0xFF0f0a1f),
              const Color(0xFF1a0a2e),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.redGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF2d0a0a),
              const Color(0xFF1a0a0a),
              _controller.value,
            )!,
            const Color(0xFF000000),
            Color.lerp(
              const Color(0xFF1f0a0a),
              const Color(0xFF2d0a0a),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.greenGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF0a2d0a),
              const Color(0xFF0a1a0a),
              _controller.value,
            )!,
            const Color(0xFF000000),
            Color.lerp(
              const Color(0xFF0a1f0a),
              const Color(0xFF0a2d0a),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
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
            Color.lerp(
              const Color(0xFF0D1F0D),
              const Color(0xFF1A3A1A),
              _controller.value,
            )!,
            const Color(0xFF071007),
            Color.lerp(
              const Color(0xFF142814),
              const Color(0xFF1F3D1F),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.beigeGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF1F1A12),
              const Color(0xFF302818),
              _controller.value,
            )!,
            const Color(0xFF0D0B07),
            Color.lerp(
              const Color(0xFF2A2218),
              const Color(0xFF352C1C),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.roseGoldGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF2A1A1A),
              const Color(0xFF3A2222),
              _controller.value,
            )!,
            const Color(0xFF0D0808),
            Color.lerp(
              const Color(0xFF2D1C18),
              const Color(0xFF3D2820),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.lavenderGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF1A142A),
              const Color(0xFF251C3A),
              _controller.value,
            )!,
            const Color(0xFF0A0810),
            Color.lerp(
              const Color(0xFF1E1830),
              const Color(0xFF2A2040),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.oceanTealGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF0A1F1F),
              const Color(0xFF0F2D2A),
              _controller.value,
            )!,
            const Color(0xFF050E0E),
            Color.lerp(
              const Color(0xFF0D2525),
              const Color(0xFF123530),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.sunsetPeachGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF2A1810),
              const Color(0xFF3A2215),
              _controller.value,
            )!,
            const Color(0xFF0D0905),
            Color.lerp(
              const Color(0xFF2D1A12),
              const Color(0xFF3D2618),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.mintGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF0D2018),
              const Color(0xFF143025),
              _controller.value,
            )!,
            const Color(0xFF060E0A),
            Color.lerp(
              const Color(0xFF10281E),
              const Color(0xFF18382A),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.dustyRoseGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF221418),
              const Color(0xFF301C22),
              _controller.value,
            )!,
            const Color(0xFF0D080A),
            Color.lerp(
              const Color(0xFF28181E),
              const Color(0xFF352028),
              _controller.value,
            )!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
    }
  }

  Widget _buildCustomImageBackground() {
    final imagePath = ref.read(wallpaperProvider.notifier).customImagePath;

    if (imagePath != null && File(imagePath).existsSync()) {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildGradientBackground();
        },
      );
    }

    return _buildGradientBackground();
  }
}
