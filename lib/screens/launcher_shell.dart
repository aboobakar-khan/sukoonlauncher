import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/theme_provider.dart';
import '../services/offline_content_manager.dart';
import '../widgets/edge_swipe_wrapper.dart';
import 'home_clock_screen.dart';
import 'widget_dashboard_screen.dart';
import 'app_list_screen.dart';
import 'productivity_hub_screen.dart';
import '../features/quran/screens/surah_list_screen.dart';
import '../features/hadith_dua/screens/minimalist_hadith_screen.dart';
import '../features/hadith_dua/screens/minimalist_dua_screen.dart';

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

  // Home is at index 2 (middle)
  static const int _homeIndex = 2;
  
  // Gesture tracking for smooth Samsung-like navigation
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragStartPage = 0;
  bool _isDragging = false;
  bool _isHorizontalDrag = false;
  bool _gestureDecided = false;
  bool _isAnimating = false;
  
  // Thresholds - tuned for reliable detection
  static const double _decisionThreshold = 15.0; // Slightly higher for accuracy
  static const double _horizontalBias = 1.2; // Favor horizontal slightly

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _homeIndex);
    _animController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);
    
    // Listen for page changes to reset animation state
    _pageController.addListener(_onPageChanged);
  }
  
  void _onPageChanged() {
    // Reset animation flag when page settles
    if (_pageController.page != null) {
      final page = _pageController.page!;
      final isSettled = (page - page.round()).abs() < 0.001;
      if (isSettled && !_isDragging) {
        _isAnimating = false;
      }
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }
  
  void _onDragStart(DragStartDetails details) {
    // Don't start new gesture if animation is in progress
    if (_isAnimating) return;
    
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _dragStartPage = _pageController.page ?? _homeIndex.toDouble();
    _isDragging = true;
    _isHorizontalDrag = false;
    _gestureDecided = false;
  }
  
  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating) return;
    
    final dx = details.globalPosition.dx - _dragStartX;
    final dy = details.globalPosition.dy - _dragStartY;
    
    // Decide direction once we've moved enough
    if (!_gestureDecided) {
      final absDx = dx.abs();
      final absDy = dy.abs();
      
      if (absDx > _decisionThreshold || absDy > _decisionThreshold) {
        // Check if this is a horizontal swipe
        _isHorizontalDrag = absDx > absDy * _horizontalBias;
        _gestureDecided = true;
        
        if (!_isHorizontalDrag) {
          // Not horizontal, stop tracking
          _isDragging = false;
          return;
        }
      } else {
        return; // Wait for more movement
      }
    }
    
    // Smooth 1:1 finger tracking
    if (_isHorizontalDrag) {
      final screenWidth = MediaQuery.of(context).size.width;
      final pageDelta = -dx / screenWidth;
      final newPage = (_dragStartPage + pageDelta).clamp(0.0, 4.0);
      
      // Use jumpToPage for smoother tracking without animation conflicts
      if (_pageController.hasClients) {
        _pageController.jumpTo(newPage * screenWidth);
      }
    }
  }
  
  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging || !_isHorizontalDrag || _isAnimating) {
      _isDragging = false;
      return;
    }
    
    final velocity = details.velocity.pixelsPerSecond.dx;
    final currentPage = _pageController.page ?? _homeIndex.toDouble();
    int targetPage;
    
    // Velocity-based page switching with clearer thresholds
    if (velocity.abs() > 800) {
      // Fast swipe - definitely go to next/prev page
      if (velocity < 0) {
        targetPage = (currentPage + 0.1).ceil().clamp(0, 4);
      } else {
        targetPage = (currentPage - 0.1).floor().clamp(0, 4);
      }
    } else if (velocity.abs() > 300) {
      // Medium swipe - consider current position
      final fraction = currentPage - currentPage.floor();
      if (velocity < 0 && fraction > 0.15) {
        targetPage = currentPage.ceil().clamp(0, 4);
      } else if (velocity > 0 && fraction < 0.85) {
        targetPage = currentPage.floor().clamp(0, 4);
      } else {
        targetPage = currentPage.round().clamp(0, 4);
      }
    } else {
      // Slow/no velocity - snap to nearest with 40% threshold
      final fraction = currentPage - currentPage.floor();
      if (fraction > 0.4) {
        targetPage = currentPage.ceil().clamp(0, 4);
      } else {
        targetPage = currentPage.floor().clamp(0, 4);
      }
    }
    
    _isDragging = false;
    
    // Smooth animation to target with completion tracking
    _isAnimating = true;
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    ).then((_) {
      _isAnimating = false;
    }).catchError((_) {
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref.watch(wallpaperProvider);
    
    // Initialize offline content manager for automatic background downloads
    ref.read(offlineContentProvider);

    // Block system back gesture for launcher
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Background
            _buildBackground(wallpaper),

            // LEFT edge - swipe right to go to previous page
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 40,
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity > 200) {
                    // Swipe right - go to previous page
                    final currentPage = (_pageController.page ?? _homeIndex).round();
                    if (currentPage > 0) {
                      _pageController.animateToPage(
                        currentPage - 1,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // RIGHT edge - swipe left to go to next page
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 40,
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -200) {
                    // Swipe left - go to next page
                    final currentPage = (_pageController.page ?? _homeIndex).round();
                    if (currentPage < 4) {
                      _pageController.animateToPage(
                        currentPage + 1,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Custom gesture handler for smooth Samsung-like navigation
            GestureDetector(
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              behavior: HitTestBehavior.translucent,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  IslamicHubScreen(pageController: _pageController),  // Index 0
                  const WidgetDashboardScreen(),  // Index 1
                  const HomeClockScreen(),        // Index 2 (HOME)
                  const AppListScreen(),          // Index 3
                  const ProductivityHubScreen(),  // Index 4
                ],
              ),
            ),
          ],
        ),
      ),
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
        // 🐪 Camel desert gradient - warm sand tones
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

/// Islamic Hub - Quran, Hadith, Dua with clean tabs
class IslamicHubScreen extends ConsumerStatefulWidget {
  final PageController pageController;
  
  const IslamicHubScreen({super.key, required this.pageController});

  @override
  ConsumerState<IslamicHubScreen> createState() => _IslamicHubScreenState();
}

class _IslamicHubScreenState extends ConsumerState<IslamicHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);

    void navigateToDashboard() {
      widget.pageController.animateToPage(
        1, // Dashboard is at index 1
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header with 3 tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  // Quran tab
                  _buildTabButton(0, 'Quran', themeColor.color),
                  const SizedBox(width: 8),
                  // Hadith tab
                  _buildTabButton(1, 'Hadith', themeColor.color),
                  const SizedBox(width: 8),
                  // Dua tab
                  _buildTabButton(2, 'Dua', themeColor.color),
                ],
              ),
            ),

            // Content with edge swipe
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  EdgeSwipeWrapper(
                    onSwipeRight: navigateToDashboard,
                    child: const SurahListScreen(),
                  ),
                  EdgeSwipeWrapper(
                    onSwipeRight: navigateToDashboard,
                    child: const MinimalistHadithScreen(),
                  ),
                  EdgeSwipeWrapper(
                    onSwipeRight: navigateToDashboard,
                    child: const MinimalistDuaScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, Color themeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final isSelected = _tabController.index == index;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? themeColor.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected 
                      ? themeColor.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected 
                      ? Colors.white 
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
