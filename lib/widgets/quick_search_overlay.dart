import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import '../models/installed_app.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/recent_apps_provider.dart';
import '../providers/productivity_provider.dart';
import '../providers/launcher_page_provider.dart';
import '../providers/screen_time_provider.dart';
import '../screens/settings_screen.dart';
import '../utils/usage_permission_helper.dart';
import 'blocked_app_screen.dart';
import 'app_session_timer_sheet.dart';

/// Quick Search Overlay — One UI–style pull-down panel
/// 
/// Layout (top → bottom):
///   1. "Quick Access" header + Settings gear
///   2. "SUGGESTED" label
///   3. 4-column × 2-row grid of recent apps (text + letter avatar, full names)
///   4. Search bar (auto-focuses keyboard)
///   5. Dismiss hint
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
  Timer? _autoLaunchDebounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
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

    // Auto-open keyboard when panel slides in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoLaunchDebounce?.cancel();
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
      // Cancel pending debounce — user is still typing
      _autoLaunchDebounce?.cancel();
      if (query.length >= 2) {
        _autoLaunchDebounce = Timer(const Duration(milliseconds: 300), () {
          _checkAutoLaunch();
        });
      }
    }
  }

  void _checkAutoLaunch() {
    if (_hasAutoLaunched || _searchQuery.length < 2) return;

    final filteredApps = ref.read(installedAppsProvider.notifier).filterApps(_searchQuery);

    // Fire when the search narrows to exactly ONE result.
    // No full-name match required — if only one app matches, that's the one.
    if (filteredApps.length == 1) {
      final app = filteredApps.first;

      final blocker = ref.read(appBlockRuleProvider.notifier);
      if (blocker.isAppBlocked(app.packageName)) return;

      _hasAutoLaunched = true;
      HapticFeedback.lightImpact();

      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _launchApp(app);
      });
    }
  }

  Future<void> _launchApp(InstalledApp app) async {
    _searchFocus.unfocus();

    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(app.packageName)) {
      HapticFeedback.heavyImpact();
      widget.onDismiss();
      if (mounted) _showBlockedMessage(app.appName);
      return;
    }

    // ── App Time Intent: ask "how long?" before launch ──
    final screenTime = ref.read(screenTimeProvider);
    int? timerMinutes;
    if (screenTime.featureEnabled && screenTime.hasTimerFor(app.packageName)) {
      // Ensure Usage Access is granted — required for precision timing
      if (!mounted) return;
      final hasPermission = await UsagePermissionHelper.ensureGranted(context);
      if (!hasPermission) {
        widget.onDismiss();
        return;
      }

      final config = screenTime.appConfigs[app.packageName];
      final defaultMins = config?.defaultMinutes ?? 15;

      if (!mounted) return;
      // Show prompt — user picks a time or dismisses to go back
      final chosenMinutes = await AppSessionPrompt.show(
        context,
        packageName: app.packageName,
        appName: app.appName,
        defaultMinutes: defaultMins,
      );
      // User dismissed (back/swipe) → go back, DON'T launch the app
      if (chosenMinutes == null || chosenMinutes <= 0) {
        widget.onDismiss();
        return;
      }

      timerMinutes = chosenMinutes;
    }

    ref.read(recentAppsProvider.notifier).addRecent(app.packageName);
    widget.onDismiss();

    // Launch the app FIRST — user sees it open directly.
    try {
      await InstalledApps.startApp(app.packageName);
    } catch (_) {}

    // Now that the app is visible, start the timed session on native side
    if (timerMinutes != null) {
      ref.read(screenTimeProvider.notifier).startSession(
        app.packageName, app.appName, timerMinutes,
      );
    }

    // Jump to home AFTER app is covering the screen — invisible to user.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return; // widget may have been disposed by the time timer fires
      final pageCtrl = ref.read(launcherPageControllerProvider);
      if (pageCtrl != null && pageCtrl.hasClients) {
        final current = pageCtrl.page?.round() ?? 2;
        if (current != 2) pageCtrl.jumpToPage(2);
      }
    });
  }

  void _showBlockedMessage(String appName) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => BlockedAppScreen(
        appName: appName,
        autoDismiss: true,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void _dismiss() {
    _searchFocus.unfocus();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final installedAppsNotifier = ref.watch(installedAppsProvider.notifier);
    final allApps = ref.watch(installedAppsProvider);
    final recentPackages = ref.watch(recentAppsProvider);
    
    final filteredApps = _searchQuery.isEmpty 
        ? <InstalledApp>[]
        : installedAppsNotifier.filterApps(_searchQuery).take(8).toList();
    
    // Recent apps — up to 8 for 4×2 grid
    final recentApps = <InstalledApp>[];
    for (final packageName in recentPackages) {
      final app = allApps.where((a) => a.packageName == packageName).firstOrNull;
      if (app != null && recentApps.length < 8) {
        recentApps.add(app);
      }
    }

    // Choose what to show in the grid
    final bool isSearching = _searchQuery.isNotEmpty;
    final gridApps = isSearching ? filteredApps : recentApps;
    final sectionTitle = isSearching ? 'Results' : 'Suggested apps';
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // ── Dismiss tap area ──
            GestureDetector(
              onTap: _dismiss,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -400) {
                  _dismiss();
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.6 * _fadeAnimation.value),
              ),
            ),
            
            // ── Panel ──
            SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Card ──
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Header: Quick Access + Settings gear ──
                                Row(
                                  children: [
                                    Text(
                                      'Quick Access',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.2,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () {
                                        widget.onDismiss();
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                        );
                                      },
                                      child: Container(
                                        width: 38, height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                        child: Icon(
                                          Icons.settings_rounded,
                                          color: Colors.white.withValues(alpha: 0.45),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // ── Section label ──
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    sectionTitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // ── 4×2 App Grid ──
                                _buildAppGrid(gridApps),

                                const SizedBox(height: 16),

                                // ── Search bar at bottom ──
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(14),
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
                                        color: Colors.white.withValues(alpha: 0.3),
                                        fontSize: 16,
                                      ),
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(left: 12, right: 6),
                                        child: Icon(
                                          Icons.search_rounded,
                                          color: themeColor.color.withValues(alpha: 0.55),
                                          size: 22,
                                        ),
                                      ),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                                      suffixIcon: _searchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.close_rounded,
                                                color: Colors.white.withValues(alpha: 0.4),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                _onSearchChanged('');
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // ── Dismiss hint ──
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          'swipe up or tap outside to close',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 11,
                            letterSpacing: 1,
                            decoration: TextDecoration.none,
                          ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 4×2 Grid — One UI style, text-only centered names, no icons
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAppGrid(List<InstalledApp> apps) {
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            _searchQuery.isNotEmpty ? 'No apps found' : 'No recent apps yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
    }

    // Build rows of 4 — max 2 rows (8 apps)
    final List<Widget> rows = [];
    final int total = apps.length.clamp(0, 8);
    for (int i = 0; i < total; i += 4) {
      final rowApps = apps.sublist(i, (i + 4).clamp(0, total));
      rows.add(
        Row(
          children: [
            for (int j = 0; j < 4; j++) ...[
              Expanded(
                child: j < rowApps.length
                    ? _buildTextTile(rowApps[j])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          rows[i],
        ],
      ],
    );
  }

  Widget _buildTextTile(InstalledApp app) {
    final isBlocked = ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);

    return GestureDetector(
      onTap: () => _launchApp(app),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            app.appName,
            style: TextStyle(
              color: isBlocked
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.3,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
