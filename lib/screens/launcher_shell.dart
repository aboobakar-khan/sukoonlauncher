import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/amoled_provider.dart';
import '../services/offline_content_manager.dart';
import 'home_clock_screen.dart';
import 'widget_dashboard_screen.dart';
import 'app_list_screen.dart';
import 'productivity_hub_screen.dart';
import '../features/quran/screens/surah_list_screen.dart';
import '../features/hadith_dua/screens/minimalist_hadith_screen.dart';
import '../features/hadith_dua/screens/minimalist_dua_screen.dart';
import '../providers/zen_mode_provider.dart';
import 'zen_mode_active_screen.dart';

/// Professional spring-based page scroll physics (like Samsung/Pixel launchers)
class _LauncherPagePhysics extends ScrollPhysics {
  const _LauncherPagePhysics({super.parent});

  @override
  _LauncherPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _LauncherPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.8,       // Light mass = fast response
    stiffness: 150,  // High stiffness = snappy settle
    damping: 18,     // Good damping = no overshoot, smooth stop
  );

  @override
  double get dragStartDistanceMotionThreshold => 3.5; // Respond to very slight drags

  @override
  double get minFlingVelocity => 50; // Easy to trigger fling (low threshold)

  @override
  double get maxFlingVelocity => 8000; // Allow fast flings
}

/// Main launcher shell with swipeable pages
/// Layout: [Islamic Hub] ← [Dashboard] ← [HOME] → [App List] → [Productivity]
class LauncherShell extends ConsumerStatefulWidget {
  const LauncherShell({super.key});

  @override
  ConsumerState<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends ConsumerState<LauncherShell>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  double _currentPage = 2.0; // Track current page for dots

  // Home is at index 2 (middle)
  static const int _homeIndex = 2;
  static const int _totalPages = 5;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _homeIndex, viewportFraction: 1.0);
    _pageController.addListener(_onPageChanged);
    _animController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    // 🧘 ZEN MODE SURVIVAL: Check if Zen Mode is active (survives restart/reboot)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final zen = ref.read(zenModeProvider);
      if (zen.isActive && !zen.hasExpired) {
        // Zen Mode is still active — immediately navigate to lockdown screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ZenModeActiveScreen(),
          ),
        );
      } else if (zen.isActive && zen.hasExpired) {
        // Timer expired while app was closed — clean up
        ref.read(zenModeProvider.notifier).endZenMode();
      }
    });
  }

  void _onPageChanged() {
    if (_pageController.page != null) {
      setState(() {
        _currentPage = _pageController.page!;
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref.watch(wallpaperProvider);
    final isAmoled = ref.watch(amoledProvider);
    
    // Initialize offline content manager for automatic background downloads
    ref.read(offlineContentProvider);

    // Use effective wallpaper: AMOLED forces pure black
    final effectiveWallpaper = isAmoled ? WallpaperType.black : wallpaper;

    // Block system back gesture for launcher
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            _buildBackground(effectiveWallpaper),

            // PageView with professional spring-based physics
            PageView(
              controller: _pageController,
              physics: const _LauncherPagePhysics(),
              clipBehavior: Clip.hardEdge,
              children: [
                IslamicHubScreen(pageController: _pageController),  // Index 0
                const WidgetDashboardScreen(),  // Index 1
                const HomeClockScreen(),        // Index 2 (HOME)
                const AppListScreen(),          // Index 3
                const ProductivityHubScreen(),  // Index 4
              ],
            ),

            // ── Page indicator dots ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
              child: _buildPageDots(),
            ),
          ],
        ),
      ),
    );
  }

  /// Subtle page indicator dots
  Widget _buildPageDots() {
    const labels = ['Islam', 'Dashboard', 'Home', 'Apps', 'Focus'];
    final int activePage = _currentPage.round().clamp(0, _totalPages - 1);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (i) {
        final isActive = i == activePage;
        // Calculate proximity for smooth animation
        final distance = (_currentPage - i).abs().clamp(0.0, 1.0);
        final dotOpacity = isActive ? 0.9 : (0.2 + (1.0 - distance) * 0.15).clamp(0.15, 0.35);
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: isActive ? 18 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: dotOpacity),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBackground(WallpaperType wallpaper) {
    if (wallpaper == WallpaperType.customImage) {
      final imagePath = ref.read(wallpaperProvider.notifier).customImagePath;
      if (imagePath != null && File(imagePath).existsSync()) {
        return Positioned.fill(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: _getWallpaperGradient(wallpaper),
            ),
          );
        },
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
            Color.lerp(const Color(0xFF0a0a0a), const Color(0xFF1a1a1a), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0f0f0f), const Color(0xFF1a1a1a), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.desertGradient:
        // 🌙 Desert gradient - warm sand tones
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1A150D), const Color(0xFF2A1F12), _animController.value)!,
            const Color(0xFF0A0805),
            Color.lerp(const Color(0xFF1F180E), const Color(0xFF2A1F12), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.blueGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0d1b2a), const Color(0xFF1b263b), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0f1f2f), const Color(0xFF1b263b), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.purpleGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1a0a2e), const Color(0xFF16213e), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0f0a1f), const Color(0xFF1a0a2e), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.redGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2d0a0a), const Color(0xFF1a0a0a), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF1f0a0a), const Color(0xFF2d0a0a), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.greenGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0a2d0a), const Color(0xFF0a1a0a), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0a1f0a), const Color(0xFF0a2d0a), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.customImage:
        return const LinearGradient(colors: [Colors.black, Colors.black]);
    }
  }
}

/// Islamic Hub - Clean card-based entry to Quran, Hadith, Dua
class IslamicHubScreen extends ConsumerStatefulWidget {
  final PageController pageController;
  
  const IslamicHubScreen({super.key, required this.pageController});

  @override
  ConsumerState<IslamicHubScreen> createState() => _IslamicHubScreenState();
}

class _IslamicHubScreenState extends ConsumerState<IslamicHubScreen> {

  static const _gold = Color(0xFFC2A366);
  static const _green = Color(0xFF7BAE6E);

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.04),

              // Header
              Text(
                'Islamic Hub',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bismillah — start your journey',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // 3 large cards — 2 columns top, 1 full width bottom
              Expanded(
                child: Column(
                  children: [
                    // Row: Quran + Hadith
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildHubCard(
                              context,
                              icon: Icons.menu_book_rounded,
                              title: 'Quran',
                              subtitle: '114 Surahs',
                              color: _gold,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const _IslamicSubScreen(title: 'Quran', child: SurahListScreen())));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildHubCard(
                              context,
                              icon: Icons.library_books_rounded,
                              title: 'Hadith',
                              subtitle: '9 Collections',
                              color: _green,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => _IslamicSubScreen(title: 'Hadith', child: MinimalistHadithScreen())));
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Full width: Dua
                    Expanded(
                      flex: 2,
                      child: _buildHubCard(
                        context,
                        icon: Icons.front_hand_rounded,
                        title: 'Dua & Adhkar',
                        subtitle: '14 categories · Morning & Evening adhkar',
                        color: accent,
                        isWide: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const _IslamicSubScreen(title: 'Dua & Adhkar', child: MinimalistDuaScreen())));
                        },
                      ),
                    ),

                    // Swipe hint
                    Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swipe_right_rounded, size: 14, color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(width: 6),
                          Text(
                            'Swipe right for Dashboard →',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.15),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isWide ? 22 : 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(icon, color: color.withValues(alpha: 0.8), size: 24),
              ),
            ),
            const Spacer(),
            // Title + Subtitle
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isWide ? 20 : 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper screen for Islamic sub-screens (Quran, Hadith, Dua)
/// Provides proper background, SafeArea, and back navigation
class _IslamicSubScreen extends StatelessWidget {
  final String title;
  final Widget child;
  const _IslamicSubScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    const creamBg = Color(0xFFFDF6EC);
    const richBrown = Color(0xFF2C1810);
    const warmBrown = Color(0xFF5C4033);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: creamBg,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: creamBg,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: creamBg,
        body: SafeArea(
          child: Column(
            children: [
              // Minimal back header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: richBrown.withOpacity(0.6),
                        size: 22,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: richBrown.withOpacity(0.85),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Child screen
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
