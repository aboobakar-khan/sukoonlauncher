import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/hive_box_manager.dart';
import '../services/native_app_blocker_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 📬 NOTIFICATION FILTER — Curated notification feed inside the launcher
//
// Psychology-informed design:
//  • Users choose WHICH apps' notifications appear → restores control
//  • Notifications grouped by app with smart deduplication
//  • "Digest mode" batches non-urgent notifications → reduces dopamine hits
//  • Quiet hours support → aligns with prayer/focus times
//  • Shows notification count badge BUT no sound/vibration → awareness not
//    interruption
//
// Battery efficiency:
//  • NotificationListenerService is system-managed (zero polling)
//  • Notifications cached in-memory on Kotlin side, Flutter pulls on demand
//  • No background Flutter isolate — all native
//  • Only wakes Flutter via MethodChannel when user views notification feed
// ═══════════════════════════════════════════════════════════════════════════════

/// Single notification entry captured from Android NotificationListenerService
class CapturedNotification {
  final String key;               // Android notification key (for dismissal)
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final DateTime postedAt;
  final bool isOngoing;           // Ongoing (media player, etc.) — don't clear
  final bool wasSuppressed;       // Was this notification suppressed by our filter?

  const CapturedNotification({
    required this.key,
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.postedAt,
    this.isOngoing = false,
    this.wasSuppressed = false,
  });

  factory CapturedNotification.fromMap(Map<String, dynamic> map) {
    return CapturedNotification(
      key: map['key'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['postedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isOngoing: map['isOngoing'] as bool? ?? false,
      wasSuppressed: map['wasSuppressed'] as bool? ?? false,
    );
  }
}

/// Group of notifications from the same app
class NotificationGroup {
  final String packageName;
  final String appName;
  final List<CapturedNotification> notifications;

  const NotificationGroup({
    required this.packageName,
    required this.appName,
    required this.notifications,
  });

  int get count => notifications.length;
  DateTime get latestTime => notifications.isEmpty
      ? DateTime.now()
      : notifications.map((n) => n.postedAt).reduce((a, b) => a.isAfter(b) ? a : b);
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class NotificationFilterState {
  final bool featureEnabled;                      // Master toggle
  final bool hasPermission;                       // NotificationListener granted
  final Set<String> allowedPackages;              // Apps user chose to filter
  final List<CapturedNotification> notifications; // Current notifications
  final bool isLoading;
  final int totalSuppressed;                      // Lifetime suppressed count

  const NotificationFilterState({
    this.featureEnabled = false,
    this.hasPermission = false,
    this.allowedPackages = const {},
    this.notifications = const [],
    this.isLoading = false,
    this.totalSuppressed = 0,
  });

  NotificationFilterState copyWith({
    bool? featureEnabled,
    bool? hasPermission,
    Set<String>? allowedPackages,
    List<CapturedNotification>? notifications,
    bool? isLoading,
    int? totalSuppressed,
  }) => NotificationFilterState(
    featureEnabled: featureEnabled ?? this.featureEnabled,
    hasPermission: hasPermission ?? this.hasPermission,
    allowedPackages: allowedPackages ?? this.allowedPackages,
    notifications: notifications ?? this.notifications,
    isLoading: isLoading ?? this.isLoading,
    totalSuppressed: totalSuppressed ?? this.totalSuppressed,
  );

  /// Notifications that were suppressed by the native filter.
  /// Only shows notifications with `wasSuppressed == true` — these are the ones
  /// the Kotlin service actually cancelled from the system notification bar.
  /// Previously also included `!allowedPackages.contains(n.packageName)` which
  /// caused overcounting: pre-populated active notifications (from onListenerConnected)
  /// from non-allowed apps were counted even though they weren't suppressed.
  List<CapturedNotification> get filteredNotifications {
    if (!featureEnabled) return [];
    return notifications
        .where((n) => n.wasSuppressed)
        .toList();
  }

  /// Group intercepted notifications by app
  List<NotificationGroup> get groupedNotifications {
    final filtered = filteredNotifications;
    final grouped = <String, List<CapturedNotification>>{};

    for (final n in filtered) {
      grouped.putIfAbsent(n.packageName, () => []).add(n);
    }

    final groups = grouped.entries.map((e) => NotificationGroup(
      packageName: e.key,
      appName: e.value.first.appName,
      notifications: e.value..sort((a, b) => b.postedAt.compareTo(a.postedAt)),
    )).toList()
      ..sort((a, b) => b.latestTime.compareTo(a.latestTime));

    return groups;
  }

  /// Total unread count (for badge on home screen)
  int get totalCount => filteredNotifications.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class NotificationFilterNotifier extends StateNotifier<NotificationFilterState> {
  Box? _configBox;
  Timer? _pollTimer;

  NotificationFilterNotifier() : super(const NotificationFilterState()) {
    _init();
  }

  // Default productive apps that should be ALLOWED (pass-through) out of the box.
  // Users can toggle them off anytime. These cover the most common work/comms apps.
  static const Set<String> _defaultAllowedPackages = {
    // Messaging & Communication
    'com.whatsapp',
    'com.whatsapp.w4b',            // WhatsApp Business
    'com.google.android.gm',       // Gmail
    'com.microsoft.office.outlook', // Outlook
    'com.microsoft.teams',         // Microsoft Teams
    'com.slack',                   // Slack
    'com.discord',                 // Discord
    'org.telegram.messenger',      // Telegram
    'com.facebook.orca',           // Messenger
    'com.skype.raider',            // Skype
    // Productivity
    'com.google.android.calendar', // Google Calendar
    'com.microsoft.teams2',
    'com.google.android.apps.tasks', // Google Tasks
    'com.todoist.android.Todoist',  // Todoist
    'com.microsoft.launcher',
    // Phone & SMS (always allow calls/texts)
    'com.android.phone',
    'com.android.mms',
    'com.google.android.dialer',
    'com.samsung.android.messaging',
    'com.google.android.apps.messaging', // Google Messages
  };

  Future<void> _init() async {
    _configBox = await HiveBoxManager.get('notification_filter_config');

    final enabled = _configBox!.get('featureEnabled', defaultValue: false) as bool;
    final allowedList = _configBox!.get('allowedPackages', defaultValue: null);

    Set<String> allowed;
    if (allowedList == null) {
      // First launch — seed with default productive apps
      allowed = Set<String>.from(_defaultAllowedPackages);
      _configBox!.put('allowedPackages', allowed.toList());
    } else {
      allowed = (allowedList is List)
          ? allowedList.cast<String>().toSet()
          : <String>{};
      // If saved list is somehow empty, re-seed defaults
      if (allowed.isEmpty) {
        allowed = Set<String>.from(_defaultAllowedPackages);
        _configBox!.put('allowedPackages', allowed.toList());
      }
    }

    final hasPermission = await NativeAppBlockerService.hasNotificationListenerPermission();
    final totalSuppressed = await NativeAppBlockerService.getTotalSuppressed();

    state = state.copyWith(
      featureEnabled: enabled,
      allowedPackages: allowed,
      hasPermission: hasPermission,
      totalSuppressed: totalSuppressed,
    );

    // Sync allowed packages to native service on startup
    await NativeAppBlockerService.updateAllowedPackages(
      allowed.toList(),
      enabled: enabled,
    );

    // If enabled, start polling for new notifications
    if (enabled && hasPermission) {
      _startPolling();
    }
  }

  Future<void> _save() async {
    _configBox ??= await HiveBoxManager.get('notification_filter_config');
    _configBox!.put('featureEnabled', state.featureEnabled);
    _configBox!.put('allowedPackages', state.allowedPackages.toList());
  }

  /// Push allowed packages + enabled state to the native listener service
  /// so it can suppress non-allowed notifications from the system bar.
  Future<void> _syncAllowedToNative() async {
    await NativeAppBlockerService.updateAllowedPackages(
      state.allowedPackages.toList(),
      enabled: state.featureEnabled,
    );
  }

  /// Check permission status (call when returning from settings)
  Future<void> recheckPermission() async {
    final has = await NativeAppBlockerService.hasNotificationListenerPermission();
    state = state.copyWith(hasPermission: has);
    if (has && state.featureEnabled) {
      _startPolling();
    }
  }

  // ── Master toggle ──

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(featureEnabled: enabled);
    await _save();
    await _syncAllowedToNative();
    // Explicitly show/remove hint notification in system bar
    await NativeAppBlockerService.showHintNotification();
    if (enabled && state.hasPermission) {
      _startPolling();
      await refreshNotifications();
    } else {
      _stopPolling();
    }
  }

  // ── App filter management ──

  Future<void> addAllowedApp(String packageName) async {
    final updated = Set<String>.from(state.allowedPackages)..add(packageName);
    state = state.copyWith(allowedPackages: updated);
    await _save();
    await _syncAllowedToNative();
    // Refresh so the feed reflects the updated suppression state immediately
    await refreshNotifications();
  }

  Future<void> removeAllowedApp(String packageName) async {
    final updated = Set<String>.from(state.allowedPackages)..remove(packageName);
    state = state.copyWith(allowedPackages: updated);
    await _save();
    await _syncAllowedToNative();
    // Refresh so the feed reflects the updated suppression state immediately
    await refreshNotifications();
  }

  Future<void> toggleApp(String packageName) async {
    if (state.allowedPackages.contains(packageName)) {
      await removeAllowedApp(packageName);
    } else {
      await addAllowedApp(packageName);
    }
  }

  // ── Notification data ──

  /// Pull latest notifications from native service
  Future<void> refreshNotifications() async {
    if (!state.featureEnabled || !state.hasPermission) return;

    state = state.copyWith(isLoading: true);
    try {
      final rawList = await NativeAppBlockerService.getCachedNotifications();
      final totalSuppressed = await NativeAppBlockerService.getTotalSuppressed();
      final notifications = rawList
          .map((m) => CapturedNotification.fromMap(m))
          .toList()
        ..sort((a, b) => b.postedAt.compareTo(a.postedAt));

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        totalSuppressed: totalSuppressed,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Dismiss a single notification
  Future<void> dismissNotification(String key) async {
    await NativeAppBlockerService.clearNotification(key);
    state = state.copyWith(
      notifications: state.notifications.where((n) => n.key != key).toList(),
    );
  }

  /// Dismiss all notifications
  Future<void> dismissAll() async {
    await NativeAppBlockerService.clearAllNotifications();
    state = state.copyWith(notifications: []);
  }

  // ── Background polling ──
  // The native NotificationListenerService already captures notifications
  // instantly via the Android callback. This poll only syncs the cached
  // list from native → Flutter state.
  //
  // 60 seconds is more than sufficient: the native side already holds
  // the data and users rarely stare at the notification feed continuously.
  // Previously 30s — doubled to reduce battery drain from periodic
  // platform-channel round-trips + state emissions.

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refreshNotifications();
    });
    // Also fetch immediately
    refreshNotifications();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final notificationFilterProvider =
    StateNotifierProvider<NotificationFilterNotifier, NotificationFilterState>(
  (ref) => NotificationFilterNotifier(),
);
