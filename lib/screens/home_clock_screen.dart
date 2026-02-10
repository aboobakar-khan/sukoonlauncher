import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import '../providers/theme_provider.dart';
import '../providers/clock_style_provider.dart';
import '../providers/time_format_provider.dart';
import '../providers/clock_opacity_provider.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/quick_action_provider.dart';
import '../providers/productivity_provider.dart';
import '../services/app_settings_service.dart';
import '../widgets/blocked_app_screen.dart';
import '../widgets/clock_variants.dart';
import '../widgets/iftar_countdown_widget.dart';
import '../widgets/quick_search_overlay.dart';
import '../widgets/offline_download_indicator.dart';
import '../providers/ramadan_provider.dart';
import 'app_list_screen.dart';
import 'favorite_picker_screen.dart';

/// Home Clock Screen - Minimalist clock and date display
class HomeClockScreen extends ConsumerStatefulWidget {
  const HomeClockScreen({super.key});

  @override
  ConsumerState<HomeClockScreen> createState() => _HomeClockScreenState();
}

class _HomeClockScreenState extends ConsumerState<HomeClockScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  // No cache needed - favorites stored permanently in Hive with app names
  
  // Vertical gesture tracking
  double _verticalDragStart = 0;
  static const double _swipeThreshold = 100;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Swipe UP → Open App List
  void _onSwipeUp() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            const AppListScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Swipe DOWN → Open Quick Search
  void _onSwipeDown() {
    HapticFeedback.lightImpact();
    showQuickSearchOverlay(context);
  }

  Future<void> _launchApp(String packageName) async {
    // Check app blocker
    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(packageName)) {
      if (mounted) {
        _showBlockedAppScreen(packageName);
      }
      return;
    }

    // Launch the app
    try {
      // Special handling for Google Pay - use native intent
      if (packageName.contains('paisa') || packageName.contains('pay')) {
        await AppSettingsService.launchGooglePay();
      } else {
        await InstalledApps.startApp(packageName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot open app: $e')));
      }
    }
  }

  void _showBlockedAppScreen(String packageName) {
    final allApps = ref.read(installedAppsProvider);
    final appName = allApps
        .where((a) => a.packageName == packageName)
        .map((a) => a.appName)
        .firstOrNull ?? packageName.split('.').last;
    
    BlockedAppScreen.showAsDialog(context, appName);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final clockStyle = ref.watch(clockStyleProvider);
    final timeFormat = ref.watch(timeFormatProvider);
    final clockOpacity = ref.watch(clockOpacityProvider);
    final favorites = ref.watch(favoriteAppsProvider);

    return GestureDetector(
      // Vertical swipe gestures (Samsung-style)
      onVerticalDragStart: (details) {
        _verticalDragStart = details.globalPosition.dy;
      },
      onVerticalDragEnd: (details) {
        final delta = details.globalPosition.dy - _verticalDragStart;
        final velocity = details.primaryVelocity ?? 0;
        
        // Swipe UP (negative delta, high velocity)
        if (delta < -_swipeThreshold || velocity < -500) {
          _onSwipeUp();
        }
        // Swipe DOWN (positive delta, high velocity)
        else if (delta > _swipeThreshold || velocity > 500) {
          _onSwipeDown();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(), // Disable scroll, we handle gestures
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: Stack(
              children: [
                // Main content
                Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  
                  // Subtle offline download indicator
                  const OfflineDownloadIndicator(),
                  
                  const SizedBox(height: 30),

                  // Clock widget based on selected style at top center
                  Center(
                    child: _buildClockWidget(
                      clockStyle,
                      themeColor,
                      timeFormat,
                      clockOpacity.value,
                    ),
                  ),

                  // 🌙 Ramadan Iftar Countdown (shows only when active)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: IftarCountdownWidget(),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),

                  const SizedBox(height: 40),
                ],
              ),

              // Favorite apps at the bottom (or empty state for first-time users)
              Positioned(
                left: 20,
                right: 20,
                bottom: 59 + MediaQuery.of(context).padding.bottom,
                child: favorites.isNotEmpty
                    ? _buildFavoriteApps(themeColor)
                    : _buildEmptyFavoritesHint(themeColor),
              ),

              // Quick action buttons at the corners bottom
              // Phone button - left corner
              Positioned(
                left: 20,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: GestureDetector(
                  onTap: () => _handleQuickAction(
                    'phone',
                    ref.read(quickActionProvider).phoneApp,
                    themeColor,
                  ),
                  onLongPress: () =>
                      _showAppSelectionDialog('phone', themeColor),
                  child: Icon(
                    Icons.call,
                    size: 28,
                    color: themeColor.color.withValues(alpha: 0.7),
                  ),
                ),
              ),

              // Camera button - right corner
              Positioned(
                right: 20,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: GestureDetector(
                  onTap: () => _handleQuickAction(
                    'camera',
                    ref.read(quickActionProvider).cameraApp,
                    themeColor,
                  ),
                  onLongPress: () =>
                      _showAppSelectionDialog('camera', themeColor),
                  child: Icon(
                    Icons.camera_alt,
                    size: 28,
                    color: themeColor.color.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildClockWidget(
    ClockStyle style,
    AppThemeColor themeColor,
    TimeFormat timeFormat,
    double opacityMultiplier,
  ) {
    switch (style) {
      case ClockStyle.digital:
        return DigitalClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.analog:
        return AnalogClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.minimalist:
        return MinimalistClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.bold:
        return BoldClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.compact:
        return CompactClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.modern:
        return ModernClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.retro:
        return RetroClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.elegant:
        return ElegantClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
      case ClockStyle.binary:
        return BinaryClockWidget(
          time: _currentTime,
          themeColor: themeColor,
          timeFormat: timeFormat,
          opacityMultiplier: opacityMultiplier,
        );
    }
  }

  Widget _buildFavoriteApps(AppThemeColor themeColor) {
    // Get favorites directly from provider - instant, no cache, no API calls
    final favorites = ref.watch(favoriteAppsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: Text(
              'FAVORITES',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w400,
                color: themeColor.color.withValues(alpha: 0.4),
              ),
            ),
          ),

          // Favorite app names (text-only, instant performance)
          ...(favorites
              .take(7)
              .map(
                (favoriteApp) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: () => _launchApp(favoriteApp.packageName),
                    child: Text(
                      favoriteApp.appName,
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w300,
                        color: themeColor.color.withValues(alpha: 1.0),
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmptyFavoritesHint(AppThemeColor themeColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to app list screen - swipe right
        // We'll use a PageController command through a callback
        // For now, show a helpful dialog
        _showAddFavoritesDialog(themeColor);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated hint icon
          Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: themeColor.color.withValues(alpha: 0.4),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'QUICK ACCESS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w400,
                  color: themeColor.color.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main hint text
          Text(
            'Add your favorite apps',
            style: TextStyle(
              fontSize: 16,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w300,
              color: themeColor.color.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap here or swipe right → App List',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w300,
              color: themeColor.color.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFavoritesDialog(AppThemeColor themeColor) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritePickerScreen()),
    );
  }

  Future<void> _handleQuickAction(
    String actionType,
    String? selectedApp,
    AppThemeColor themeColor,
  ) async {
    if (selectedApp == null) {
      // Show app selection dialog
      _showAppSelectionDialog(actionType, themeColor);
    } else {
      // Launch the saved app
      _launchApp(selectedApp);
    }
  }

  Future<void> _showAppSelectionDialog(
    String actionType,
    AppThemeColor themeColor,
  ) async {
    final installedApps = ref.read(installedAppsProvider);

    if (installedApps.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No apps available'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Select ${actionType == 'phone' ? 'Phone' : 'Camera'} App',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: installedApps.length,
            itemBuilder: (context, index) {
              final app = installedApps[index];
              return ListTile(
                title: Text(
                  app.appName,
                  style: TextStyle(
                    color: themeColor.color.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),

                onTap: () async {
                  // Save the selection
                  if (actionType == 'phone') {
                    await ref
                        .read(quickActionProvider.notifier)
                        .setPhoneApp(app.packageName);
                  } else {
                    await ref
                        .read(quickActionProvider.notifier)
                        .setCameraApp(app.packageName);
                  }

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${app.appName} set for ${actionType == 'phone' ? 'Phone' : 'Camera'}',
                      ),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// Blocked app screen now uses shared BlockedAppScreen widget
