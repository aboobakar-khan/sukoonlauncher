import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/amoled_provider.dart';
import '../providers/islamic_theme_provider.dart';
import '../providers/screen_time_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../services/native_app_blocker_service.dart';
import '../services/offline_content_manager.dart';
import '../widgets/app_session_timer_sheet.dart';
import '../widgets/year_dots_wallpaper.dart';
import 'package:installed_apps/installed_apps.dart';
import 'home_clock_screen.dart';
import 'widget_dashboard_screen.dart';
import 'app_list_screen.dart';
import 'productivity_hub_screen.dart';
import '../features/quran/screens/surah_list_screen.dart';
import '../features/hadith_dua/screens/minimalist_hadith_screen.dart';
import '../features/hadith_dua/screens/minimalist_dua_screen.dart';
import '../providers/zen_mode_provider.dart';
import '../providers/launcher_page_provider.dart';
import '../features/prayer_alarm/services/prayer_alarm_service.dart';
import 'zen_mode_active_screen.dart';
import '../services/app_update_service.dart';

/// Launcher page physics — any horizontal swipe from a non-home page
/// navigates directly to the Home page (index 2). This gives the user
/// a Samsung One-UI / iOS Springboard feel where Home is always one
/// swipe away, regardless of which page they are on.
///
/// Uses [ClampingScrollPhysics] boundary (no overscroll bounce) and
/// Flutter's built-in [PageScrollPhysics] for snapping.
class _LauncherPagePhysics extends PageScrollPhysics {
  const _LauncherPagePhysics({super.parent});

  @override
  _LauncherPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _LauncherPagePhysics(parent: buildParent(ancestor));
  }

  // ── Boundary: hard clamp (zero overscroll at first/last page) ──
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// A [ScrollBehavior] applied to every vertical [Scrollable] inside each
/// PageView page.
///
/// Provides:
/// 1. [ClampingScrollPhysics] — no overscroll bounce on inner scrollables.
/// 2. Reduced [dragStartDistanceMotionThreshold] (3.5px vs default 18px) —
///    the inner scrollable responds to vertical drag much sooner after a
///    horizontal swipe settles, while still giving the gesture arena enough
///    movement to correctly disambiguate horizontal vs vertical intent.
class _PageInnerScrollBehavior extends ScrollBehavior {
  const _PageInnerScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const _ImmediateClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

/// [ClampingScrollPhysics] with reduced (but not zero) drag-start threshold.
///
/// The default threshold is null → interpreted as [kTouchSlop] (18 logical
/// pixels). This means 18px of vertical movement is ignored — perceived as
/// a dead zone where the screen "shakes" because neither axis has won.
///
/// Setting it to 0 causes the opposite problem: the inner scrollable
/// greedily claims the pointer on the very first pixel of movement, before
/// the gesture arena can determine if the user intended horizontal or
/// vertical. This makes horizontal page swipes feel broken.
///
/// 3.5px is the sweet spot: small enough that vertical scroll starts
/// almost instantly after horizontal swipe settles, but large enough that
/// the arena can still correctly disambiguate horizontal vs vertical intent.
class _ImmediateClampingScrollPhysics extends ClampingScrollPhysics {
  const _ImmediateClampingScrollPhysics({super.parent});

  @override
  _ImmediateClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ImmediateClampingScrollPhysics(parent: buildParent(ancestor));
  }

  /// Reduced threshold: claim vertical drag after just 3.5px of movement
  /// instead of the default 18px (kTouchSlop). This is enough for the
  /// gesture arena to determine direction but small enough to feel instant.
  @override
  double get dragStartDistanceMotionThreshold => 3.5;
}

/// Main launcher shell with swipeable pages
/// Layout: [Islamic Hub] ← [Dashboard] ← [HOME] → [App List] → [Productivity]
class LauncherShell extends ConsumerStatefulWidget {
  const LauncherShell({super.key});

  @override
  ConsumerState<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends ConsumerState<LauncherShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  late AnimationController _animController;
  bool _animRunning = false;
  bool _offlineInitialized = false;
  bool _hasShownLauncherPrompt = false; // Only show once per session
  int _yearDotsKey = 0; // Increments on resume to refresh year dots

  /// True while a programmatic animateToPage/jumpToPage is in flight.
  /// While set, [didChangeAppLifecycleState] skips its setState to avoid
  /// a double-rebuild that competes with the in-flight page animation.
  bool _pageAnimating = false;

  /// Timestamp of last pause — used to distinguish quick permission dialogs
  /// (GPS, notification) from genuine app switches when deciding whether to
  /// pop all routes on resume.
  DateTime? _lastPausedAt;

  /// True when the last lifecycle pause was caused by the screen turning OFF
  /// (lock button / auto-lock timeout) rather than the user switching to
  /// another app. When this is true, resume must NEVER reset the page or
  /// pop any pushed routes — the user expects to land exactly where they left.
  bool _wasScreenOff = false;

  /// Debounce: timestamp of last "times up" overlay shown.
  /// Prevents the overlay from appearing in a loop on rapid resume cycles.
  DateTime? _lastTimesUpShown;

  /// SharedPreferences key for persisting the last active page index.
  static const _kLastPageKey = 'launcher_last_page_index';

  // Home is at index 2 (middle)
  static const int _homeIndex = 2;

  static const _launcherChannel = MethodChannel('com.sukoon.launcher/launcher');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _homeIndex, viewportFraction: 1.0);
    // Share the page controller so other screens can navigate
    Future.microtask(() {
      ref.read(launcherPageControllerProvider.notifier).state = _pageController;
    });
    _animController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // ── RESTORE LAST PAGE: Jump to where the user was before screen-off/restart ──
    // Reads the persisted page index and jumps there after the first frame.
    // This ensures that locking/unlocking the phone never drops the user back
    // to the home page when they were on the Quran, App List, Settings, etc.
    _restoreLastPage();

    // 🧘 ZEN MODE SURVIVAL: Check if Zen Mode is active (survives restart/reboot)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final zen = ref.read(zenModeProvider);
      if (zen.isActive && !zen.hasExpired) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ZenModeActiveScreen(),
          ),
        );
      } else if (zen.isActive && zen.hasExpired) {
        ref.read(zenModeProvider.notifier).endZenMode();
      }
      // Initialize offline content manager ONCE (moved out of build)
      if (!_offlineInitialized) {
        _offlineInitialized = true;
        ref.read(offlineContentProvider);
      }
      // Check default launcher on first launch
      _checkDefaultLauncher();

      // ── In-App Update: check silently 3s after launch ──
      // Delayed so the launcher UI is fully visible before any dialog appears.
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        AppUpdateService().initialize(
          onUpdateReady: () {
            if (mounted) AppUpdateService().showUpdateReadyDialog(context);
          },
        );
        _checkForUpdate();
      });
    });
  }

  /// Restore the last active page index from SharedPreferences.
  /// Called once in initState — jumps the PageView after the first frame
  /// so the user lands on the page they were on before lock/restart.
  Future<void> _restoreLastPage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt(_kLastPageKey) ?? _homeIndex;
      // Only restore non-home pages — home is already the default
      if (savedPage != _homeIndex) {
        // Wait until the PageView has laid out its viewport
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(savedPage);
          }
        });
      }
    } catch (_) {
      // SharedPreferences failure is non-fatal — just stay on home page
    }
  }

  /// Persist the current page index so it survives screen-off/on and restarts.
  Future<void> _saveCurrentPage(int pageIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastPageKey, pageIndex);
    } catch (_) {}
  }

  /// Check if the screen is currently off using the native PowerManager.
  /// Sets [_wasScreenOff] = true when the screen is off so that the
  /// resumed handler knows this is a lock/unlock cycle (not an app switch).
  static const _powerChannel = MethodChannel('com.sukoon.launcher/power');

  Future<void> _checkIsScreenOff() async {
    try {
      final isInteractive = await _powerChannel.invokeMethod<bool>('isInteractive') ?? true;
      _wasScreenOff = !isInteractive;
    } catch (_) {
      // Channel not implemented yet — fall back to heuristic:
      // If the pause-to-resume gap is very short (< 800ms) it's almost
      // certainly a quick screen-off/on cycle rather than an app switch.
      // We'll refine this in the resumed handler.
      _wasScreenOff = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // ── GOING AWAY (fully backgrounded) ──
      // Record when we paused — used on resume to distinguish quick
      // permission dialogs / screen lock cycles from genuine app switches.
      _lastPausedAt = DateTime.now();

      // Check native PowerManager to detect screen-off vs app-switch.
      // _checkIsScreenOff() is async — it sets _wasScreenOff before
      // the resumed event fires (screen-off/on always takes > 500ms).
      _checkIsScreenOff();

      // Do NOT jump to home page here. The paused state fires during:
      //   1. Genuine backgrounding (home button / app switch)
      //   2. Navigator.push transitions (brief lifecycle bounce)
      //   3. Permission dialogs / system overlays
      //   4. Screen turning off (auto-lock / power button)
      // Jumping PageView during case 2/4 causes the user to land on the
      // wrong page when they pop back.

      // Reset the flag so resumed won't fight with an old animation.
      _pageAnimating = false;
    }

    // inactive = system overlay (permission dialog, phone call, notification
    // shade). Do NOT jump to home or pop routes — user expects to stay put.
    if (state == AppLifecycleState.inactive) {
      _lastPausedAt ??= DateTime.now(); // Only set if not already paused
    }

    if (state == AppLifecycleState.resumed) {
      // ── COMING BACK ──
      final pauseDuration = _lastPausedAt != null
          ? DateTime.now().difference(_lastPausedAt!)
          : const Duration(seconds: 10);
      _lastPausedAt = null; // Reset for next cycle

      // SCREEN-OFF UNLOCK: The user simply locked and unlocked the phone
      // while staying inside the launcher. Never reset the page position or
      // pop any routes — they expect to see exactly what they had before.
      //
      // Two ways to detect a screen-off cycle:
      //  1. _wasScreenOff flag set by the native power channel (most reliable).
      //  2. Heuristic fallback: lock/unlock cycles are very quick — the phone
      //     turns off, user picks it up and unlocks, total elapsed < 3s means
      //     it's almost certainly a screen-off/on rather than an app switch.
      //     (An app switch of < 3s goes through Home → other app → back, which
      //     requires at least 2-3 taps and is practically never < 1.5s anyway.)
      final isScreenOffCycle = _wasScreenOff || pauseDuration.inSeconds < 3;
      _wasScreenOff = false;

      // Only take action for genuine app returns (> 3s away, not a lock cycle).
      final isGenuineReturn = !isScreenOffCycle && pauseDuration.inMilliseconds > 3000;

      if (isScreenOffCycle) {
        // Lock/unlock: restore the saved page silently — no route popping,
        // no home-jump, no visual disruption to the user.
        _restoreLastPage();
      } else if (isGenuineReturn) {
        final alarmShowing = PrayerAlarmService.isAlarmScreenShowing;
        final hasModalRoute = Navigator.of(context).canPop();

        if (!alarmShowing) {
          // Only pop routes AND jump to home when away for a VERY LONG time
          // (> 5 minutes). This is a deliberate threshold increase from 30s:
          //
          // • 30s was too aggressive — a quick Quran reading, checking
          //   settings, or leaving the phone on the desk triggered a reset.
          // • 5 minutes means the user genuinely stepped away and returning
          //   to the home page makes contextual sense.
          // • Screen-off cycles (any duration) are already excluded above
          //   via isScreenOffCycle, so this only fires on real app-switch returns.
          final isVeryLongReturn = pauseDuration.inMinutes >= 5;
          if (isVeryLongReturn) {
            if (hasModalRoute) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }

            // Jump to home page only on very long genuine app-switch returns.
            if (_pageController.hasClients) {
              final currentPage = _pageController.page?.round() ?? _homeIndex;
              if (currentPage != _homeIndex) {
                _pageController.jumpToPage(_homeIndex);
                _saveCurrentPage(_homeIndex);
              }
            }
          }
          // Short / medium returns (3s–5min): do nothing — preserve page and routes.
        }
        // If alarmShowing == true: do absolutely nothing — the alarm screen
        // manages its own lifecycle and must not be disturbed on resume.
      }

      // Schedule non-critical visual updates for AFTER the first frame.
      // These don't affect interactivity, so they can wait.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Refresh year dots wallpaper ONLY if that wallpaper is active.
        // Avoids triggering a full shell rebuild (all 5 pages) on every resume.
        final currentWallpaper = ref.read(wallpaperProvider);
        final isAmoled = ref.read(amoledProvider);
        if (!isAmoled && currentWallpaper == WallpaperType.yearDots && mounted) {
          setState(() => _yearDotsKey++);
        }
      });

      // Skip the platform channel call entirely while a page animation is
      // running — the async round-trip would queue behind the animation and
      // add latency to gesture recognition on the very next frame.
      if (!_hasShownLauncherPrompt && !_pageAnimating) {
        Future.microtask(_checkDefaultLauncher);
      }

      // ── Check if native blocker has a "time's up" event pending ──
      Future.microtask(_checkTimesUp);

      // ── Zen Mode safety net: auto-end if timer expired while away ──
      // The ZenModeNotifier has its own periodic check, but this catches
      // the edge case where the provider was not ticking (e.g. app restart).
      final zen = ref.read(zenModeProvider);
      if (zen.isActive && zen.hasExpired) {
        ref.read(zenModeProvider.notifier).endZenMode();
      }

      // ── In-App Update: re-check on resume in case update finished downloading ──
      // The service's _isCheckingForUpdate guard prevents duplicate checks.
      // Also handles the case where user downloaded update via Play Store and
      // switched back — the "ready to install" dialog should appear.
      if (isGenuineReturn) {
        Future.microtask(_checkForUpdate);
      }

      // NOTE: Subscription checks removed — all features are free (donation model)
    }
  }

  /// Poll native for pending "time's up" intent and show the overlay.
  /// Called on every resume — native service sets this when a timed session
  /// expires while the user is inside the timed app.
  Future<void> _checkTimesUp() async {
    if (!mounted) return;

    // Debounce: don't show overlay if we showed one in the last 5 seconds.
    // This prevents the infinite loop where "Take me out" → resume → overlay → repeat.
    if (_lastTimesUpShown != null &&
        DateTime.now().difference(_lastTimesUpShown!).inSeconds < 5) {
      return;
    }

    try {
      final data = await NativeAppBlockerService.getPendingTimesUp();
      if (data == null || !mounted) return;

      final packageName = data['packageName'] as String? ?? '';
      if (packageName.isEmpty) return;

      final extensionsUsed = data['extensionsUsed'] as int? ?? 0;
      final nativeMinutesSpent = data['minutesSpent'] as int? ?? 0;

      // Compute minutes spent from the active session (or use native value)
      final session = ref.read(screenTimeProvider).activeSession;
      final minutesSpent = nativeMinutesSpent > 0
          ? nativeMinutesSpent
          : (session != null ? session.elapsedMinutes : 0);

      // Fetch today + week usage for the overlay
      final todayDuration = ref.read(screenTimeProvider.notifier).getTodayUsage(packageName);
      final weekDuration = ref.read(screenTimeProvider.notifier).getWeekUsage(packageName);

      // Resolve human-readable app name — the active session may already
      // be cleared (e.g. user tapped "take me out" then re-opened from recents),
      // so look it up from installed apps as the primary source.
      final installedApps = ref.read(installedAppsProvider);
      final matchingApp = installedApps
          .where((a) => a.packageName == packageName)
          .toList();
      final appName = matchingApp.isNotEmpty
          ? matchingApp.first.appName
          : (session?.appName ?? _friendlyName(packageName));

      _lastTimesUpShown = DateTime.now();

      if (!mounted) return;
      TimesUpOverlay.showAsDialog(
        context,
        appName: appName,
        minutesSpent: minutesSpent.clamp(1, 99999),
        extensionsUsed: extensionsUsed,
        todayUsage: todayDuration,
        weekUsage: weekDuration,
        onExit: () {
          // End the session and go home
          ref.read(screenTimeProvider.notifier).endSession();
        },
        onExtend: (mins) {
          // Extend both Flutter and native session
          ref.read(screenTimeProvider.notifier).extendSession(mins);
          // Re-launch the app so user returns to it
          try { InstalledApps.startApp(packageName); } catch (_) {}
        },
      );
    } catch (_) {}
  }

  /// Convert a raw package name like "com.whatsapp.android" into a
  /// human-readable fallback name ("whatsapp") when neither the installed-apps
  /// list nor the active session provides a label.
  String _friendlyName(String packageName) {
    final parts = packageName.split('.');
    // Drop common noise segments
    final meaningful = parts.where(
      (p) => p != 'com' && p != 'org' && p != 'net' && p != 'android' && p != 'app',
    );
    final label = meaningful.isNotEmpty ? meaningful.last : parts.last;
    // Capitalise first letter
    return label.isNotEmpty
        ? '${label[0].toUpperCase()}${label.substring(1)}'
        : label;
  }

  /// Navigate to the Home page (index 2) with instant gesture release.
  ///
  /// Strategy: use a very short animation (180ms) instead of 350ms so that
  /// the [DrivenScrollActivity] finishes quickly and the gesture arena is
  /// unblocked for horizontal swipes as fast as possible.
  /// The [_pageAnimating] flag prevents competing work (lifecycle setState,
  /// platform channel calls) from piling up while the animation runs.
  void _navigateToHome() {
    if (_pageAnimating) return;
    final currentPage = _pageController.page?.round() ?? _homeIndex;
    if (currentPage == _homeIndex) return;

    final distance = (currentPage - _homeIndex).abs();

    _pageAnimating = true;

    // Scale duration by distance so multi-page jumps feel proportional
    // but never too slow. 1 page = 250ms, 2 pages = 350ms.
    final duration = Duration(milliseconds: 200 + (distance * 75).clamp(0, 150));

    _pageController
        .animateToPage(
          _homeIndex,
          duration: duration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(_onPageAnimationDone);
  }

  void _onPageAnimationDone() {
    if (!mounted) return;
    _pageAnimating = false;
  }

  // ── Gesture-arena release: kill ballistic on new pointer down ──

  /// Called by the [Listener] wrapping the [PageView] on every
  /// [PointerDownEvent], BEFORE any gesture recognizer receives the event.
  ///
  /// If the PageView's scroll position is in the tail phase of a ballistic
  /// settle (very close to the target page but not yet idle), we force it
  /// to snap to the exact page. This converts the scroll activity to idle
  /// and frees the gesture arena so inner vertical scrollables can claim
  /// the pointer immediately.
  ///
  /// IMPORTANT: We only snap when drift is very small (< 8px). If the page
  /// is still far from the target, the ballistic is doing meaningful work
  /// and we must not interfere — otherwise horizontal swipes feel broken.
  void _killBallisticIfSettling(PointerDownEvent event) {
    if (!_pageController.hasClients) return;
    // Don't kill our own programmatic animations (e.g. _navigateToHome).
    if (_pageAnimating) return;

    final pos = _pageController.position;
    final viewportWidth = pos.viewportDimension;
    if (viewportWidth <= 0) return;

    final currentPage = (pos.pixels / viewportWidth).round();
    final targetPixels = currentPage * viewportWidth;
    final drift = (pos.pixels - targetPixels).abs();

    // Only kill ballistic tail — page is nearly settled but simulation
    // hasn't met tolerance yet. 8px is close enough that the user
    // cannot perceive the snap, but the ballistic tail can run 100-200ms
    // in this zone keeping the arena contested.
    if (drift > 0.5 && drift < 8.0) {
      pos.jumpTo(targetPixels);
    }
  }

  Future<void> _checkDefaultLauncher() async {
    if (_hasShownLauncherPrompt) return;
    try {
      final isDefault = await _launcherChannel.invokeMethod<bool>('isDefaultLauncher') ?? false;
      if (!isDefault && mounted) {
        _hasShownLauncherPrompt = true;
        _showDefaultLauncherDialog();
      }
    } catch (_) {
      // Silently ignore — platform may not support this check
    }
  }

  void _showDefaultLauncherDialog() {
    final accent = ref.read(themeColorProvider).color;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.home_rounded, color: accent, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Set as Default',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Sukoon Launcher works best as your default home app. Set it now for the full experience.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Later',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launcherChannel.invokeMethod('openHomeLauncherSettings');
            },
            style: TextButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Set Now',
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Start/stop gradient animation based on wallpaper type
  void _syncAnimController(WallpaperType wallpaper) {
    final needsAnimation = wallpaper != WallpaperType.black &&
        wallpaper != WallpaperType.customImage &&
        wallpaper != WallpaperType.islamicNamazMat &&
        wallpaper != WallpaperType.islamicInshallah &&
        wallpaper != WallpaperType.islamicFlag &&
        wallpaper != WallpaperType.islamicQuranDark &&
        wallpaper != WallpaperType.yearDots;
    
    if (needsAnimation && !_animRunning) {
      _animController.repeat(reverse: true);
      _animRunning = true;
    } else if (!needsAnimation && _animRunning) {
      _animController.stop();
      _animRunning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _animController.dispose();
    AppUpdateService().dispose();
    super.dispose();
  }

  // ── In-App Update check ──
  // Checks silently — shows a bottom-sheet style dialog only when an update
  // is actually available. Re-checked on every app resume (debounced to once
  // per session by the service's _isCheckingForUpdate guard).
  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    final hasUpdate = await AppUpdateService().checkForUpdate(silent: true);
    if (hasUpdate && mounted) {
      AppUpdateService().showUpdateDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = ref.watch(wallpaperProvider);
    final isAmoled = ref.watch(amoledProvider);
    
    // Use effective wallpaper: AMOLED forces pure black
    final effectiveWallpaper = isAmoled ? WallpaperType.black : wallpaper;

    // Start/stop gradient animation based on wallpaper type (saves GPU when not needed)
    _syncAnimController(effectiveWallpaper);

    // Back button: navigate to Home page. If already on Home, do nothing.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          final currentPage = _pageController.page?.round() ?? _homeIndex;
          if (currentPage != _homeIndex) {
            _navigateToHome();
          }
        }
      },
      child: Scaffold(
        // Prevent the Scaffold from resizing when the keyboard opens.
        // Without this, opening the keyboard on the AppList page causes the
        // PageView viewport to shrink then re-expand, producing a visible
        // horizontal bounce / jump animation.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background
            _buildBackground(effectiveWallpaper),

            // ── Ballistic-kill layer ──
            //
            // WHY THIS EXISTS:
            // After a horizontal fling, the PageView's ScrollPosition runs a
            // BallisticScrollActivity (SpringSimulation). While this activity
            // is alive — even in its very last frames when the page is already
            // visually snapped — the PageView's internal Scrollable keeps its
            // HorizontalDragGestureRecognizer registered in the gesture arena.
            // Any new pointer that arrives during this phase enters a
            // CONTESTED arena: horizontal vs vertical. The arena waits for
            // kTouchSlop (18px) of directional movement to pick a winner →
            // user perceives ~200-400ms of "shake" or blocked vertical scroll.
            //
            // SOLUTION:
            // A raw Listener sits ABOVE the PageView in the hit-test order.
            // On PointerDownEvent it checks if the PageView's ScrollPosition
            // is in a ballistic settle phase. If so, it force-jumps to the
            // current pixel offset — which internally calls goIdle() on the
            // ScrollPosition, converting BallisticScrollActivity → 
            // IdleScrollActivity. The gesture arena is now empty before any
            // gesture recognizer even sees the pointer.
            //
            // The Listener uses HitTestBehavior.translucent so the pointer
            // event continues down to the PageView and its children normally.
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _killBallisticIfSettling,
              child: PageView(
                  controller: _pageController,
                  physics: const _LauncherPagePhysics(),
                  clipBehavior: Clip.none, // Reduces per-frame clipping overhead
                  allowImplicitScrolling: true, // keeps adjacent pages alive
                  pageSnapping: true, // ensures crisp page settling
                  // Persist current page so lock/unlock restores user's position
                  onPageChanged: (index) => _saveCurrentPage(index),
                  children: [
                    // ── STABLE KEYS: pages are NEVER destroyed/recreated ──
                    //
                    // Using const keys (or no changing keys) ensures
                    // AutomaticKeepAliveClientMixin works correctly:
                    // pages stay mounted in memory permanently.
                    // Their gesture recognizers stay attached.
                    // NO rebuild on resume = instant input response.
                    ScrollConfiguration(
                      behavior: const _PageInnerScrollBehavior(),
                      child: RepaintBoundary(
                        child: IslamicHubScreen(pageController: _pageController),
                      ),
                    ),
                    ScrollConfiguration(
                      behavior: const _PageInnerScrollBehavior(),
                      child: const RepaintBoundary(
                        child: WidgetDashboardScreen(),
                      ),
                    ),
                    ScrollConfiguration(
                      behavior: const _PageInnerScrollBehavior(),
                      child: const RepaintBoundary(
                        child: HomeClockScreen(),
                      ),
                    ),
                    ScrollConfiguration(
                      behavior: const _PageInnerScrollBehavior(),
                      child: const RepaintBoundary(
                        child: AppListScreen(),
                      ),
                    ),
                    ScrollConfiguration(
                      behavior: const _PageInnerScrollBehavior(),
                      child: const RepaintBoundary(
                        child: ProductivityHubScreen(),
                      ),
                    ),
                  ],
                ),
            ),

            // ── Bottom swipe-up zone — swipe up from bottom to go Home ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 44 + MediaQuery.paddingOf(context).bottom,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: (d) {
                  final velocity = d.primaryVelocity ?? 0;
                  // Swipe UP detected (negative velocity = upward)
                  if (velocity < -300) {
                    final currentPage = _pageController.page?.round() ?? _homeIndex;
                    if (currentPage != _homeIndex) {
                      _navigateToHome();
                    }
                  }
                },
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildBackground(WallpaperType wallpaper) {
    // Year dots wallpaper — static, no gradient
    if (wallpaper == WallpaperType.yearDots) {
      final accent = ref.read(themeColorProvider).color;
      return Positioned.fill(
        child: YearDotsWallpaper(
          key: ValueKey('year_dots_$_yearDotsKey'),
          accentColor: accent,
        ),
      );
    }

    // Premium asset wallpapers
    final assetPath = wallpaperAssetPath(wallpaper);
    if (assetPath != null) {
      return Positioned.fill(
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

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
      child: RepaintBoundary(
        // Isolate the animated gradient into its own compositing layer.
        //
        // Without this, AnimatedBuilder schedules a markNeedsPaint on the
        // Positioned.fill subtree on every animation tick (~60 fps). Because
        // this Positioned is a sibling of the PageView in the same Stack,
        // the Stack's RenderObject walks all children to determine whether a
        // relayout is needed — indirectly causing the PageView's pages to
        // receive a layout pass, which changes their measured constraints by
        // sub-pixel amounts and causes cards to visually resize/bounce.
        //
        // RepaintBoundary promotes this gradient to its own layer. The
        // compositor composites it directly with the GPU without touching
        // the layout tree of any sibling — zero layout cost.
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
            Color.lerp(const Color(0xFF0D1F0D), const Color(0xFF1A3A1A), _animController.value)!,
            const Color(0xFF071007),
            Color.lerp(const Color(0xFF142814), const Color(0xFF1F3D1F), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.beigeGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1F1A12), const Color(0xFF302818), _animController.value)!,
            const Color(0xFF0D0B07),
            Color.lerp(const Color(0xFF2A2218), const Color(0xFF352C1C), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.roseGoldGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2A1A1A), const Color(0xFF3A2222), _animController.value)!,
            const Color(0xFF0D0808),
            Color.lerp(const Color(0xFF2D1C18), const Color(0xFF3D2820), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.lavenderGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1A142A), const Color(0xFF251C3A), _animController.value)!,
            const Color(0xFF0A0810),
            Color.lerp(const Color(0xFF1E1830), const Color(0xFF2A2040), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.oceanTealGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0A1F1F), const Color(0xFF0F2D2A), _animController.value)!,
            const Color(0xFF050E0E),
            Color.lerp(const Color(0xFF0D2525), const Color(0xFF123530), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.sunsetPeachGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2A1810), const Color(0xFF3A2215), _animController.value)!,
            const Color(0xFF0D0905),
            Color.lerp(const Color(0xFF2D1A12), const Color(0xFF3D2618), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.mintGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0D2018), const Color(0xFF143025), _animController.value)!,
            const Color(0xFF060E0A),
            Color.lerp(const Color(0xFF10281E), const Color(0xFF18382A), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.dustyRoseGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF221418), const Color(0xFF301C22), _animController.value)!,
            const Color(0xFF0D080A),
            Color.lerp(const Color(0xFF28181E), const Color(0xFF352028), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
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

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;

    // IMPORTANT: Do NOT use MediaQuery.of(context).size.height here.
    //
    // During a PageView horizontal swipe Flutter recomputes layout for
    // off-screen pages. When this widget reads MediaQuery.size inside build(),
    // the fractional SizedBox heights (screenHeight * 0.04) become slightly
    // different pixel values on each layout pass as the viewport shifts its
    // paintOffset. This cascades into a full re-measure of the Column → the
    // Expanded cards resize and visually "bounce" during the swipe.
    //
    // Replacing with fixed pixel values eliminates the layout dependency on
    // viewport size and makes the card sizes fully stable during swipe.
    const double topSpacing = 32.0;   // replaces screenHeight * 0.04 (~30–36px)
    const double midSpacing = 32.0;   // replaces second screenHeight * 0.04

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: Colors.black.withValues(alpha: 0.3),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: topSpacing),

              // Header + theme toggle
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: midSpacing),

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
                              color: accent,
                              onTap: () {
                                Navigator.push(context, _SmoothForwardRoute(child: const _IslamicSubScreen(title: 'Quran', child: SurahListScreen())));
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
                              color: accent,
                              onTap: () {
                                Navigator.push(context, _SmoothForwardRoute(child: _IslamicSubScreen(title: 'Hadith', child: MinimalistHadithScreen())));
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
                          Navigator.push(context, _SmoothForwardRoute(child: const _IslamicSubScreen(title: 'Dua & Adhkar', child: MinimalistDuaScreen())));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
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
/// Samsung One UI-style forward navigation transition.
///
/// Combines a horizontal slide (20% offset → center) with fade + subtle scale
/// for a smooth, premium feel. The incoming screen slides in from the right
/// while fading up, and the outgoing screen stays mostly still — matching
/// Samsung's "shared axis" forward/backward pattern.
/// Apple-style page route — full-width iOS slide with interactive swipe-back.
class _SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  _SmoothForwardRoute({required Widget child})
      : super(builder: (_) => child);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// Respects Islamic theme mode (light cream / pure dark)
class _IslamicSubScreen extends ConsumerWidget {
  final String title;
  final Widget child;
  const _IslamicSubScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(islamicThemeColorsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.background,
        statusBarIconBrightness: colors.statusBarBrightness,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: colors.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
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
                        color: colors.textSecondary.withValues(alpha: 0.6),
                        size: 22,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text.withValues(alpha: 0.85),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Theme toggle in sub-screen too
                    GestureDetector(
                      onTap: () {
                        ref.read(islamicThemeProvider.notifier).toggle();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          ref.watch(islamicThemeProvider).icon,
                          color: colors.accent.withValues(alpha: 0.6),
                          size: 20,
                        ),
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
