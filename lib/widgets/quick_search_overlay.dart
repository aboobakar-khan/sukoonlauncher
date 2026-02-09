import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import '../models/installed_app.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/recent_apps_provider.dart';
import '../providers/productivity_provider.dart';

/// Quick Search Overlay - Samsung-style pull-down search
/// 
/// Features:
/// - Appears on swipe down from home
/// - INSTANT search using apps already in memory
/// - Auto-opens single match
/// - Text-only minimalist design (no icons)
class QuickSearchOverlay extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;

  const QuickSearchOverlay({super.key, required this.onDismiss});

  @override
  ConsumerState<QuickSearchOverlay> createState() => _QuickSearchOverlayState();
}

class _QuickSearchOverlayState extends ConsumerState<QuickSearchOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  String _searchQuery = '';
  bool _hasAutoLaunched = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200), // Faster animation
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    
    // Auto-focus search instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _hasAutoLaunched = false;
      });
      
      // Check for auto-launch
      _checkAutoLaunch();
    }
  }

  void _checkAutoLaunch() {
    if (_hasAutoLaunched || _searchQuery.isEmpty) return;
    
    final installedAppsNotifier = ref.read(installedAppsProvider.notifier);
    final filteredApps = installedAppsNotifier.filterApps(_searchQuery);
    
    // Auto-launch when exactly 1 result
    if (filteredApps.length == 1) {
      // 🛡️ Don't auto-launch blocked apps
      final blocker = ref.read(appBlockRuleProvider.notifier);
      if (blocker.isAppBlocked(filteredApps.first.packageName)) return;

      _hasAutoLaunched = true;
      HapticFeedback.lightImpact();
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _launchApp(filteredApps.first);
        }
      });
    }
  }

  Future<void> _launchApp(InstalledApp app) async {
    _searchFocus.unfocus();

    // 🛡️ Check app blocker — block ALL channels
    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(app.packageName)) {
      HapticFeedback.heavyImpact();
      widget.onDismiss();
      if (mounted) {
        _showBlockedMessage(app.appName);
      }
      return;
    }

    // Track as recent app
    ref.read(recentAppsProvider.notifier).addRecent(app.packageName);

    // Dismiss and launch
    widget.onDismiss();
    try {
      await InstalledApps.startApp(app.packageName);
    } catch (e) {
      // Silent fail
    }
  }

  void _showBlockedMessage(String appName) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _BlockedAppOverlay(
        appName: appName,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void _dismiss() {
    _searchFocus.unfocus();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    
    // Get apps directly from memory - INSTANT!
    final installedAppsNotifier = ref.watch(installedAppsProvider.notifier);
    final allApps = ref.watch(installedAppsProvider);
    final recentPackages = ref.watch(recentAppsProvider);
    
    // Filter apps instantly from memory
    final filteredApps = _searchQuery.isEmpty 
        ? <InstalledApp>[]
        : installedAppsNotifier.filterApps(_searchQuery).take(8).toList();
    
    // Get recent apps (most recently launched)
    final recentApps = <InstalledApp>[];
    for (final packageName in recentPackages) {
      final app = allApps.where((a) => a.packageName == packageName).firstOrNull;
      if (app != null && recentApps.length < 6) {
        recentApps.add(app);
      }
    }
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Tap to dismiss background
            GestureDetector(
              onTap: _dismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                  _dismiss();
                }
              },
              onHorizontalDragEnd: (details) {
                // Swipe left or right to dismiss
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() > 300) {
                  _dismiss();
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.6 * _fadeAnimation.value),
              ),
            ),
            
            // Search panel
            SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search bar
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText: 'Search apps...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: themeColor.color.withValues(alpha: 0.7),
                                      ),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                color: Colors.white.withValues(alpha: 0.5),
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                                
                                // Results or recent apps (INSTANT!)
                                if (_searchQuery.isNotEmpty)
                                  _buildSearchResults(filteredApps, themeColor)
                                else
                                  _buildRecentApps(recentApps, themeColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Hint
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: Text(
                        'swipe up or tap outside to close',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          letterSpacing: 1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(List<InstalledApp> apps, AppThemeColor themeColor) {
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No apps found',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESULTS',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 12),
        ...apps.map((app) => _buildAppTile(app, themeColor)),
      ],
    );
  }

  Widget _buildRecentApps(List<InstalledApp> apps, AppThemeColor themeColor) {
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Type to search apps...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 10,
            letterSpacing: 2,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 12),
        // Text-only list (no icons)
        ...apps.map((app) => _buildAppTile(app, themeColor)),
      ],
    );
  }

  Widget _buildAppTile(InstalledApp app, AppThemeColor themeColor) {
    final isBlocked = ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);
    
    return GestureDetector(
      onTap: () => _launchApp(app),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        child: Row(
          children: [
            // Text only - NO icon!
            Expanded(
              child: Text(
                app.appName,
                style: TextStyle(
                  color: isBlocked 
                      ? Colors.white.withValues(alpha: 0.25) 
                      : Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (isBlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8915A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, 
                        color: const Color(0xFFE8915A).withValues(alpha: 0.6), size: 10),
                    const SizedBox(width: 3),
                    Text('BLOCKED', style: TextStyle(
                      color: const Color(0xFFE8915A).withValues(alpha: 0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      decoration: TextDecoration.none,
                    )),
                  ],
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.2),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the quick search overlay
void showQuickSearchOverlay(BuildContext context) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => QuickSearchOverlay(
      onDismiss: () => entry.remove(),
    ),
  );
  
  Overlay.of(context).insert(entry);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ BLOCKED APP OVERLAY — Shown when trying to open blocked app from search
// ═══════════════════════════════════════════════════════════════════════════════

class _BlockedAppOverlay extends StatefulWidget {
  final String appName;
  final VoidCallback onDismiss;

  const _BlockedAppOverlay({required this.appName, required this.onDismiss});

  @override
  State<_BlockedAppOverlay> createState() => _BlockedAppOverlayState();
}

class _BlockedAppOverlayState extends State<_BlockedAppOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _quotes = [
    {'text': 'Verily, with hardship comes ease.', 'ref': 'Quran 94:6'},
    {'text': 'And whoever fears Allah, He will make a way out for him.', 'ref': 'Quran 65:2'},
    {'text': 'Indeed, Allah is with the patient.', 'ref': 'Quran 2:153'},
    {'text': 'So remember Me; I will remember you.', 'ref': 'Quran 2:152'},
  ];

  late Map<String, String> _quote;

  @override
  void initState() {
    super.initState();
    _quote = _quotes[DateTime.now().millisecond % _quotes.length];
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: _dismiss,
          child: Material(
            color: Colors.black.withValues(alpha: 0.85 * _controller.value),
            child: Center(
              child: Opacity(
                opacity: _controller.value,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * _controller.value),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE8915A).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Shield icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8915A).withValues(alpha: 0.1),
                            border: Border.all(
                              color: const Color(0xFFE8915A).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.shield_rounded,
                            color: const Color(0xFFE8915A).withValues(alpha: 0.7),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${widget.appName} is blocked',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Quote
                        Text(
                          '"${_quote['text']}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFC2A366).withValues(alpha: 0.7),
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '— ${_quote['ref']}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
