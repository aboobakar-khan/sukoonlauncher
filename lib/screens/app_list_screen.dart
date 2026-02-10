import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/installed_app.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/recent_apps_provider.dart';
import '../providers/productivity_provider.dart';
import '../services/app_settings_service.dart';
import '../widgets/blocked_app_screen.dart';
import 'settings_screen.dart';

/// App List Screen - Minimalist launcher
/// Text-only, stored in Hive, loaded in memory, instant filtering
/// Smart search: auto-opens single match, case-insensitive
class AppListScreen extends ConsumerStatefulWidget {
  const AppListScreen({super.key});

  @override
  ConsumerState<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends ConsumerState<AppListScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _hasAutoLaunched = false; // Prevent multiple auto-launches
  String? _activeAlpha; // Currently highlighted letter

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text;
    if (newQuery != _searchQuery) {
      setState(() {
        _searchQuery = newQuery;
        _hasAutoLaunched = false; // Reset on new search
      });
      
      // Auto-open if single match
      _checkAutoLaunch();
    }
  }

  void _checkAutoLaunch() {
    if (_hasAutoLaunched || _searchQuery.isEmpty) return;
    
    final installedAppsNotifier = ref.read(installedAppsProvider.notifier);
    final filteredApps = installedAppsNotifier.filterApps(_searchQuery);
    
    // Auto-launch when exactly 1 result
    if (filteredApps.length == 1) {
      _hasAutoLaunched = true;
      HapticFeedback.lightImpact();
      
      // Small delay to show the match before launching
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _launchApp(filteredApps.first.packageName);
          // Clear search after launch
          _searchController.clear();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshAppList();
    }
  }

  Future<void> _refreshAppList() async {
    await ref
        .read(installedAppsProvider.notifier)
        .refreshApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchApp(String packageName) async {
    // Unfocus search when launching
    _searchFocusNode.unfocus();

    // Check app blocker
    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(packageName)) {
      if (mounted) {
        _showBlockedAppScreen(packageName);
      }
      return;
    }

    // Track as recent app
    ref.read(recentAppsProvider.notifier).addRecent(packageName);

    // Launch the app
    try {
      if (packageName.contains('paisa') || packageName.contains('googlepay')) {
        await AppSettingsService.launchGooglePay();
      } else if (packageName == 'net.one97.paytm') {
        await InstalledApps.startApp(packageName);
      } else {
        await InstalledApps.startApp(packageName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open app: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
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

  void _scrollToLetter(String letter, List<InstalledApp> apps) {
    final itemHeight = 48.0; // Approximate height of each app item (padding 12*2 + text)
    final index = apps.indexWhere(
        (app) => app.appName.toUpperCase().startsWith(letter));
    if (index != -1) {
      final offset = index * itemHeight;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      HapticFeedback.selectionClick();
      setState(() => _activeAlpha = letter);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _activeAlpha = null);
      });
    }
  }

  Widget _buildAlphabetSidebar(List<InstalledApp> apps, AppThemeColor themeColor) {
    // Get available first letters from app list
    final availableLetters = <String>{};
    for (final app in apps) {
      if (app.appName.isNotEmpty) {
        final first = app.appName[0].toUpperCase();
        if (RegExp(r'[A-Z]').hasMatch(first)) {
          availableLetters.add(first);
        }
      }
    }

    const allLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onVerticalDragStart: (details) {
            _handleAlphabetDrag(details.localPosition.dy, allLetters, availableLetters, apps, context);
          },
          onVerticalDragUpdate: (details) {
            _handleAlphabetDrag(details.localPosition.dy, allLetters, availableLetters, apps, context);
          },
          onVerticalDragEnd: (_) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) setState(() => _activeAlpha = null);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: allLetters.split('').map((letter) {
                final isAvailable = availableLetters.contains(letter);
                final isActive = _activeAlpha == letter;
                return GestureDetector(
                  onTap: isAvailable ? () => _scrollToLetter(letter, apps) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: isActive ? 24 : 20,
                    height: isActive ? 24 : 18,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(vertical: 0.5),
                    decoration: isActive
                        ? BoxDecoration(
                            color: themeColor.color.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: isActive
                            ? themeColor.color
                            : isAvailable
                                ? Colors.white.withValues(alpha: 0.55)
                                : Colors.white.withValues(alpha: 0.1),
                        fontSize: isActive ? 12 : 10,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        height: 1.0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _handleAlphabetDrag(double localY, String allLetters, Set<String> availableLetters, List<InstalledApp> apps, BuildContext context) {
    // Calculate based on the sidebar's actual rendered height
    final totalLetters = allLetters.length;
    // Each letter: 18px height + 1px margin = ~19px, active = 25px. Avg ~19px
    final sidebarHeight = totalLetters * 19.0 + 12; // 6px padding top+bottom
    final adjustedY = localY - 6; // offset for top padding
    final index = (adjustedY / (sidebarHeight - 12) * totalLetters).floor().clamp(0, totalLetters - 1);
    final letter = allLetters[index];
    if (availableLetters.contains(letter) && _activeAlpha != letter) {
      _scrollToLetter(letter, apps);
    } else if (_activeAlpha != letter) {
      setState(() => _activeAlpha = letter);
    }
  }

  void _showAppOptions(BuildContext context, InstalledApp app, WidgetRef ref) {
    final themeColor = ref.read(themeColorProvider);
    final isFav = ref.read(favoriteAppsProvider.notifier).isFavorite(app.packageName);

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                app.appName,
                style: TextStyle(
                  color: themeColor.color.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const Divider(color: Colors.white12),

            // Add/Remove from favorites
            ListTile(
              leading: Icon(
                isFav ? Icons.star : Icons.star_outline,
                color: isFav
                    ? const Color(0xFFC2A366)
                    : const Color(0xFFC2A366).withValues(alpha: 0.6),
              ),
              title: Text(
                isFav ? 'Remove from Favorites' : 'Add to Favorites',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              subtitle: !isFav
                  ? Text(
                      'Max 7 apps',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    )
                  : null,
              onTap: () async {
                final success = await ref
                    .read(favoriteAppsProvider.notifier)
                    .toggleFavorite(app.packageName, app.appName);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Max 7 favorites reached'),
                      backgroundColor: Color(0xFFE8915A),
                    ),
                  );
                } else {
                  HapticFeedback.lightImpact();
                }
              },
            ),

            // Uninstall app option
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Colors.red.shade400.withValues(alpha: 0.8),
              ),
              title: Text(
                'Uninstall app',
                style: TextStyle(
                  color: Colors.red.shade400.withValues(alpha: 0.9),
                ),
              ),
              onTap: () async {
                Navigator.pop(context);

                await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    insetPadding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 16 + MediaQuery.of(context).padding.bottom,
                    ),
                    title: Text(
                      'Uninstall ${app.appName}?',
                      style: const TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'This will uninstall the app from your device.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop(false);

                          ref
                              .read(installedAppsProvider.notifier)
                              .removeApp(app.packageName);

                          await AppSettingsService.uninstallApp(
                            app.packageName,
                          );

                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              _refreshAppList();
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                        ),
                        child: const Text('Uninstall'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allApps = ref.watch(installedAppsProvider);
    final installedAppsNotifier = ref.watch(installedAppsProvider.notifier);

    final filteredApps = installedAppsNotifier.filterApps(_searchQuery);
    final isRefreshing = installedAppsNotifier.isRefreshing;
    final themeColor = ref.watch(themeColorProvider);

    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.removeViewInsets(removeBottom: true),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: SafeArea(
          child: Column(
            children: [
              // Header with app count and settings
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${filteredApps.length} apps',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                            letterSpacing: 1.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (isRefreshing) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      child: Icon(
                        Icons.settings,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // App list with A-Z sidebar
              Expanded(
                child: allApps.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Wait a moment...',
                              style: TextStyle(
                                color: themeColor.color.withValues(alpha: 0.5),
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      )
                    : filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          'No apps found',
                          style: TextStyle(
                            color: themeColor.color.withValues(alpha: 0.3),
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(left: 24, right: 28),
                            itemCount: filteredApps.length,
                            cacheExtent: 500,
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              return _buildAppItem(app, themeColor);
                            },
                          ),
                          // A-Z alphabet sidebar (only when not searching)
                          if (_searchQuery.isEmpty)
                            _buildAlphabetSidebar(filteredApps, themeColor),
                        ],
                      ),
              ),

              // Search bar at BOTTOM
              _buildBottomSearchBar(themeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSearchBar(AppThemeColor themeColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(
            color: themeColor.color.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(
          color: themeColor.color.withValues(alpha: 0.9),
          fontSize: 17,
          letterSpacing: 0.8,
        ),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 17,
            letterSpacing: 0.5,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: themeColor.color.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: themeColor.color.withValues(alpha: 0.35), width: 1.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: themeColor.color.withValues(alpha: 0.4),
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildAppItem(InstalledApp app, AppThemeColor themeColor) {
    final isFavorite = ref
        .watch(favoriteAppsProvider.notifier)
        .isFavorite(app.packageName);
    final isBlocked = ref.watch(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _launchApp(app.packageName),
        onLongPress: () => _showAppOptions(context, app, ref),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              // Text only - no icons
              Expanded(
                child: Text(
                  app.appName,
                  style: TextStyle(
                    color: isBlocked 
                        ? Colors.white.withValues(alpha: 0.2)
                        : themeColor.color.withValues(alpha: 0.7),
                    fontSize: 17,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Blocked indicator
              if (isBlocked)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.shield_rounded, 
                      size: 12, color: const Color(0xFFE8915A).withValues(alpha: 0.4)),
                ),
              // Favorite star (subtle)
              if (isFavorite)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.star,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Blocked app screen now uses shared BlockedAppScreen widget
