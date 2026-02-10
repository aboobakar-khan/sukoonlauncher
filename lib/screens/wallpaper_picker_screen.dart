import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/wallpaper_provider.dart';

/// Wallpaper Picker Screen
class WallpaperPickerScreen extends ConsumerWidget {
  const WallpaperPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWallpaper = ref.watch(wallpaperProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Wallpaper grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: WallpaperType.values.length,
                itemBuilder: (context, index) {
                  final wallpaper = WallpaperType.values[index];
                  final isSelected = wallpaper == currentWallpaper;

                  return _buildWallpaperCard(
                    context,
                    ref,
                    wallpaper,
                    isSelected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white.withValues(alpha: 0.7),
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
              color: Colors.white.withValues(alpha: 0.9),
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
  ) {
    return GestureDetector(
      onTap: () async {
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
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
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
                  gradient: _getWallpaperGradient(wallpaper),
                  color: wallpaper == WallpaperType.customImage
                      ? Colors.black
                      : null,
                ),
                child: wallpaper == WallpaperType.customImage
                    ? _buildCustomImagePreview(ref)
                    : null,
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
                            color: Colors.white.withValues(alpha: 0.9),
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
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wallpaper.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
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
