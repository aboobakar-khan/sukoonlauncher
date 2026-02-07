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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref.watch(wallpaperProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: wallpaper == WallpaperType.customImage
              ? _buildCustomImageBackground()
              : _buildGradientBackground(),
        ),
        widget.child,
      ],
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
