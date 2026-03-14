import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:hive_flutter/hive_flutter.dart';
import '../../../utils/hive_box_manager.dart';
import '../models/prayer_alarm_config.dart';

// ─────────────────────────────────────────────────────
// TOP-LEVEL alarm callback (MUST be top-level for AOT)
// ─────────────────────────────────────────────────────

/// Called by AndroidAlarmManager in a background isolate.
/// MUST be a top-level function, NOT a static class method.
///
/// Behaviour by notification type:
///  'notification' → shows a banner notification with system sound (no wake screen)
///  'athan'        → native AlarmBroadcastReceiver already handles wake + full-screen;
///                   this callback is NOT scheduled for 'athan' type (skipped in
///                   scheduleDailyAlarms). Only runs as a fallback if native failed.
///  'silent'       → never scheduled, so this never fires.
@pragma('vm:entry-point')
Future<void> prayerAlarmCallback(int alarmId) async {
  // In isolate — re-init Hive
  try {
    await Hive.initFlutter();
  } catch (_) {}

  Box? box;
  try {
    box = await Hive.openBox('prayer_pending_alarms');
  } catch (_) {
    // Can't read box — fire a plain notification as last resort
    await PrayerAlarmService._showPrayerNotification('Prayer', 'notification');
    return;
  }

  // Look up the prayer name AND notifType by the alarm ID
  String prayerName = 'Prayer';
  String notifType = 'notification';
  final data = box.get(alarmId.toString());
  if (data is Map) {
    prayerName = data['prayer'] as String? ?? 'Prayer';
    notifType = data['notifType'] as String? ?? 'notification';
  } else {
    // Fallback: derive from alarm ID
    const idToPrayer = {
      1000: 'Fajr',
      1001: 'Dhuhr',
      1002: 'Asr',
      1003: 'Maghrib',
      1004: 'Isha',
      1005: 'Fajr',
      1006: 'Dhuhr',
      1007: 'Asr',
      1008: 'Maghrib',
      1009: 'Isha',
    };
    prayerName = idToPrayer[alarmId] ?? 'Prayer';
  }

  // 'athan' type is handled entirely by the native AlarmBroadcastReceiver.
  // This Flutter callback is NOT scheduled for 'athan' alarms — but if it
  // somehow fires (e.g. snooze fallback), skip the notification to avoid
  // a duplicate banner on top of the native full-screen alarm.
  if (notifType == 'athan') return;

  // 'notification' type: show a banner notification with system sound.
  await PrayerAlarmService._showPrayerNotification(prayerName, notifType);
}

/// Prayer alarm scheduling + notification service.
///
/// Design:
/// 1. Uses AndroidAlarmManager for exact background wakeup.
/// 2. Uses flutter_local_notifications for heads-up alarm notification.
/// 3. Notification tap opens the prayer alarm screen via Navigator payload.
/// 4. No persistent background service — only 5 exact alarms per day.
///
/// Battery impact: ~3-5% daily (same as Google Calendar reminders).
class PrayerAlarmService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Channel to communicate with AlarmActivity (native wake-screen activity).
  static const _alarmActivityChannel =
      MethodChannel('com.sukoon.launcher/alarm_activity');

  static bool _initialized = false;

  /// Global navigator key — set this from your MaterialApp.
  static Function(String prayerName)? onAlarmScreenRequested;

  /// Guard: recently dismissed prayers won't re-open the alarm screen.
  /// Maps prayer name → dismissal timestamp. Prevents resume-triggered re-open.
  static final Map<String, DateTime> _recentlyDismissed = {};

  /// Guard: prevents multiple alarm screens from being pushed simultaneously.
  /// This is the SINGLE lock that prevents the triple-screen bug.
  /// Set to the prayer name when an alarm screen is showing; null when not.
  static String? _alarmScreenShowing;

  /// Call this when the alarm screen is opened.
  static void markAlarmScreenShowing(String prayerName) {
    _alarmScreenShowing = prayerName;
  }

  /// Call this when the alarm screen is closed (dismissed/prayed/snoozed).
  static void markAlarmScreenClosed() {
    _alarmScreenShowing = null;
  }

  /// Whether an alarm screen is currently being displayed.
  static bool get isAlarmScreenShowing => _alarmScreenShowing != null;

  // ── Initialization ──────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();
    // Get device timezone name via platform channel (avoids flutter_timezone plugin)
    String currentTz;
    try {
      const platform = MethodChannel('sukoon/timezone');
      currentTz = await platform.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
    } catch (_) {
      // Fallback: try common Android timezone API via DateTime
      currentTz = DateTime.now().timeZoneName;
      // timeZoneName returns abbreviations like 'IST', convert to IANA if needed
      if (!tz.timeZoneDatabase.locations.containsKey(currentTz)) {
        currentTz = 'UTC';
      }
    }
    try {
      tz.setLocalLocation(tz.getLocation(currentTz));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Initialize alarm manager
    await AndroidAlarmManager.initialize();

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high-priority notification channel for full-screen alarm type
    const androidChannel = AndroidNotificationChannel(
      'prayer_alarm',
      'Prayer Alarms',
      description: 'Full-screen alarm for Salah times (Athan mode)',
      importance: Importance.high,
      playSound: false, // Native alarm handles sound for this channel
      enableVibration: true,
      showBadge: true,
    );

    // Create standard notification channel for banner reminder type
    const reminderChannel = AndroidNotificationChannel(
      'prayer_reminder',
      'Prayer Reminders',
      description: 'Banner notification with system sound (Notification mode)',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    // Listen for "showAlarmScreen" messages from AlarmActivity
    // (AlarmActivity calls this when the Flutter engine is ready in that process)
    _alarmActivityChannel.setMethodCallHandler((call) async {
      if (call.method == 'showAlarmScreen') {
        final prayerName = call.arguments as String? ?? 'Prayer';
        // Guard: don't push if alarm screen is already showing
        if (_alarmScreenShowing == null) {
          onAlarmScreenRequested?.call(prayerName);
        }
      }
    });

    _initialized = true;
  }

  /// Read the prayer name written by AlarmActivity into SharedPreferences.
  /// Call this on app startup and on resume — covers both cold-start and
  /// background-resume scenarios. Clears the value after reading so it
  /// isn't replayed on the next resume.
  static Future<void> checkNativeAlarmPending() async {
    // Guard: don't push another alarm screen if one is already showing
    if (_alarmScreenShowing != null) return;

    try {
      final name = await _alarmActivityChannel
          .invokeMethod<String?>('pendingPrayerName');
      if (name != null && name.isNotEmpty) {
        // Guard: don't push if alarm screen is already showing
        if (_alarmScreenShowing != null) return;
        // Check if this prayer was recently dismissed (within 10 min)
        final dismissed = _recentlyDismissed[name];
        if (dismissed != null &&
            DateTime.now().difference(dismissed).inMinutes < 10) {
          // Already dismissed — clear the SharedPrefs and skip
          await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
          return;
        }
        // Clear immediately so we don't re-show on the next resume
        await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
        // Give the widget tree time to finish building before pushing
        await Future.delayed(const Duration(milliseconds: 600));
        onAlarmScreenRequested?.call(name);
      }
    } catch (_) {
      // Platform channel not available (e.g. on iOS / desktop) — ignore
    }
  }

  /// Dismiss the keep-screen-on flag after the user acts on the alarm.
  static Future<void> dismissAlarmWakeFlags() async {
    try {
      await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
    } catch (_) {}
  }

  /// Check if app was launched by tapping a prayer notification.
  /// Call this AFTER setting [onAlarmScreenRequested].
  static Future<void> checkPendingNotificationLaunch() async {
    if (_alarmScreenShowing != null) return;

    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse != null) {
      final payload = details.notificationResponse!.payload;
      if (payload != null && payload.isNotEmpty) {
        if (_alarmScreenShowing != null) return;
        // Small delay to let the MaterialApp finish building
        await Future.delayed(const Duration(milliseconds: 500));
        if (_alarmScreenShowing != null) return;
        onAlarmScreenRequested?.call(payload);
      }
    }
  }

  /// Check for active prayer notifications and open the alarm screen.
  /// Call this when the app comes to foreground.
  static Future<void> checkActiveNotifications() async {
    // Guard: don't push another alarm screen if one is already showing
    if (_alarmScreenShowing != null) return;

    try {
      // Check if there are active prayer alarm notifications
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final activeNotifications = await android.getActiveNotifications();
        for (final notification in activeNotifications) {
          if (notification.id == null) continue;
          final id = notification.id!;
          // Flutter notifications: IDs 2000-2004
          // Native AlarmBroadcastReceiver notifications: IDs 3000-3004
          final idToPrayer = {
            2000: 'Fajr',  2001: 'Dhuhr',  2002: 'Asr',  2003: 'Maghrib',  2004: 'Isha',
            3000: 'Fajr',  3001: 'Dhuhr',  3002: 'Asr',  3003: 'Maghrib',  3004: 'Isha',
          };
          final prayerName = idToPrayer[id];
          if (prayerName != null) {
            // Check if recently dismissed — don't re-open
            final dismissed = _recentlyDismissed[prayerName];
            if (dismissed != null &&
                DateTime.now().difference(dismissed).inMinutes < 10) {
              continue; // Skip this — user already dismissed it
            }
            onAlarmScreenRequested?.call(prayerName);
            return; // Open only the first one found
          }
        }
      }
    } catch (_) {
      // If checking fails, do nothing
    }
  }

  // ── Schedule alarms ─────────────────────────────────

  /// Schedule all prayer alarms for a given day.
  ///
  /// Two alarm paths based on per-prayer [notifType]:
  ///
  ///  'notification'  → Flutter AndroidAlarmManager only.
  ///                    Fires [prayerAlarmCallback] in a background isolate which
  ///                    posts a standard banner notification with the system
  ///                    notification sound. Does NOT wake the screen.
  ///
  ///  'athan'         → Native AlarmManager → AlarmBroadcastReceiver only.
  ///                    Wakes screen, shows full-screen alarm, plays athan audio
  ///                    and then opens the PrayerAlarmScreen over the lock screen.
  ///                    The Flutter AndroidAlarmManager is NOT scheduled for this
  ///                    type to prevent a duplicate banner notification.
  ///
  ///  'silent'        → Nothing is scheduled.
  ///
  /// [prayerTimes] = { 'Fajr': 'HH:mm', ... }
  /// [enabledPrayers] = { 'Fajr': true, ... }
  /// [reminderSettings] = per-prayer notification type config
  static Future<void> scheduleDailyAlarms({
    required Map<String, String> prayerTimes,
    required Map<String, bool> enabledPrayers,
    required DateTime date,
    PrayerReminderSettings? reminderSettings,
  }) async {
    // Verify permissions before scheduling
    final notifGranted = await Permission.notification.isGranted;
    final exactAlarm = await canScheduleExactAlarms();
    if (!notifGranted || !exactAlarm) {
      debugPrint('PrayerAlarmService: Missing permissions, skipping schedule');
      return;
    }

    // Cancel previous alarms first
    await cancelAllAlarms();

    final now = DateTime.now();

    for (final entry in prayerTimes.entries) {
      final prayerName = entry.key;
      final timeStr = entry.value;
      final enabled = enabledPrayers[prayerName] ?? true;

      if (!enabled) continue;

      // Check per-prayer notification type — skip if silent
      final notifType = reminderSettings?.notifTypeFor(prayerName) ?? 'notification';
      if (notifType == 'silent') continue;

      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      final alarmTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      // Don't schedule alarms in the past
      if (alarmTime.isBefore(now)) continue;

      final alarmId = _alarmIdForPrayer(prayerName);

      if (notifType == 'notification') {
        // ── NOTIFICATION PATH ────────────────────────────────────────────────
        // Store notifType in Hive so the isolate callback knows what to show.
        await _storePendingAlarm(alarmId, prayerName, timeStr, notifType: notifType);

        // Schedule Flutter alarm manager callback → shows banner notification
        // with the system notification sound. No screen wake.
        await AndroidAlarmManager.oneShotAt(
          alarmTime,
          alarmId,
          prayerAlarmCallback,
          exact: true,
          wakeup: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
        );
      } else if (notifType == 'athan') {
        // ── ATHAN / FULL-SCREEN ALARM PATH ───────────────────────────────────
        // Native AlarmManager → AlarmBroadcastReceiver → AlarmActivity →
        // MainActivity → PrayerAlarmScreen (full-screen with sound + wake).
        //
        // We do NOT schedule a Flutter AndroidAlarmManager alarm here because:
        //  1. The native path handles wakeup + notification already.
        //  2. A parallel Flutter alarm would fire _showPrayerNotification()
        //     producing a duplicate banner on top of the full-screen alarm.
        //
        // We still write to the Hive box so that if the native alarm fires
        // while the app is alive, prayerAlarmCallback (if ever invoked) knows
        // to skip the notification for this prayer.
        await _storePendingAlarm(alarmId, prayerName, timeStr, notifType: notifType);

        try {
          await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
            'prayerName': prayerName,
            'triggerAtMillis': alarmTime.millisecondsSinceEpoch,
          });
        } catch (e) {
          debugPrint('Warning: Could not schedule native alarm for $prayerName: $e');
        }
      }
    }
  }

  /// Schedule a snooze alarm (re-notify after N minutes).
  ///
  /// [notifType] determines the path — same rules as [scheduleDailyAlarms]:
  ///  'notification' → Flutter callback only (banner notification)
  ///  'athan'        → Native AlarmManager only (full-screen wake alarm)
  static Future<void> scheduleSnooze({
    required String prayerName,
    required int minutes,
    String notifType = 'athan',
  }) async {
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final alarmId = _alarmIdForPrayer('${prayerName}_snooze');

    await _storePendingAlarm(alarmId, prayerName, '', notifType: notifType);

    if (notifType == 'notification') {
      // Banner notification path — no screen wake needed for snooze
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        alarmId,
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
    } else {
      // 'athan' / full-screen alarm path
      // Flutter callback as safety net (won't show notification for 'athan')
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        alarmId,
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
      );
      // Native alarm → wake screen
      try {
        await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
          'prayerName': prayerName,
          'triggerAtMillis': snoozeTime.millisecondsSinceEpoch,
        });
      } catch (e) {
        debugPrint('Warning: Could not schedule native snooze alarm: $e');
      }
    }
  }

  /// Cancel all scheduled prayer alarms.
  static Future<void> cancelAllAlarms() async {
    for (int i = 0; i < 12; i++) {
      await AndroidAlarmManager.cancel(1000 + i);
    }
    // Cancel native alarms (prayers + fasting)
    const alarmLabels = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', 'Suhoor', 'Iftar'];
    for (final label in alarmLabels) {
      try {
        await _alarmActivityChannel.invokeMethod('cancelNativeAlarm', {
          'prayerName': label,
        });
      } catch (_) {}
    }
    // Clear pending alarm data
    try {
      final box = await HiveBoxManager.get('prayer_pending_alarms');
      await box.clear();
    } catch (_) {}
  }

  // ── Fasting alarms (Suhoor / Iftar) ─────────────────

  /// Store fasting alarm info so the background callback can read it.
  static Future<void> storeFastingAlarm(
      int alarmId, String label, DateTime alarmTime) async {
    try {
      final box = await HiveBoxManager.get('prayer_pending_alarms');
      await box.put(alarmId.toString(), {
        'prayer': label,
        'time':
            '${alarmTime.hour.toString().padLeft(2, '0')}:${alarmTime.minute.toString().padLeft(2, '0')}',
      });
    } catch (_) {}
  }

  /// Schedule a Suhoor or Iftar alarm using the same system as prayer alarms.
  /// Uses IDs 1010 (Suhoor) and 1011 (Iftar).
  static Future<void> scheduleFastingAlarm({
    required String label,
    required DateTime alarmTime,
    required int alarmId,
  }) async {
    // ① AndroidAlarmManager — fires Dart callback in background isolate
    await AndroidAlarmManager.oneShotAt(
      alarmTime,
      alarmId,
      prayerAlarmCallback,  // same top-level callback — reads label from Hive
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );

    // ② Native AlarmManager → AlarmBroadcastReceiver (wake screen + sound)
    try {
      await _alarmActivityChannel.invokeMethod('scheduleNativeAlarm', {
        'prayerName': label,
        'triggerAtMillis': alarmTime.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Warning: Could not schedule native fasting alarm for $label: $e');
    }
  }

  // ── Show notification ───────────────────────────────

  /// Shows a prayer notification appropriate for the given [notifType].
  ///
  ///  'notification' → banner with system notification sound, no full-screen
  ///                   intent, no screen wake. User sees it in the notification
  ///                   shade and can tap to open the prayer screen.
  ///
  ///  anything else  → this should normally not be called for 'athan' (native
  ///                   handles it) but serves as a safety fallback banner if
  ///                   the native alarm was cancelled by the system.
  static Future<void> _showPrayerNotification(
    String prayerName,
    String notifType,
  ) async {
    // Ensure notifications plugin is initialized (in isolate context)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    final bool isNotificationOnly = notifType == 'notification';

    final androidDetails = AndroidNotificationDetails(
      // Use a separate channel for plain notifications so they use the
      // system sound and don't override the silent athan channel settings.
      isNotificationOnly ? 'prayer_reminder' : 'prayer_alarm',
      isNotificationOnly ? 'Prayer Reminders' : 'Prayer Alarms',
      channelDescription: isNotificationOnly
          ? 'Banner notification for Salah times'
          : 'Full-screen alarm for Salah times',
      importance: Importance.high,
      priority: Priority.high,
      category: isNotificationOnly
          ? AndroidNotificationCategory.reminder
          : AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ongoing: false,
      // For 'notification' type: play system sound so the user actually hears
      // something. The athan channel leaves sound off because native handles it.
      playSound: isNotificationOnly,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      // Only fire the full-screen intent for the athan fallback path.
      fullScreenIntent: !isNotificationOnly,
      timeoutAfter: isNotificationOnly ? 120000 : 90000,

      // Rich notification styling
      styleInformation: BigTextStyleInformation(
        _getPrayerMessage(prayerName),
        contentTitle: isNotificationOnly
            ? '🕌 ${prayerName.toUpperCase()} TIME'
            : '🕌 TIME FOR ${prayerName.toUpperCase()}',
        summaryText: isNotificationOnly
            ? 'Tap to mark as prayed'
            : 'Tap to open prayer screen',
      ),
    );

    await _notifications.show(
      _notificationIdForPrayer(prayerName),
      isNotificationOnly
          ? '🕌 ${prayerName.toUpperCase()} TIME'
          : '🕌 TIME FOR ${prayerName.toUpperCase()}',
      _getPrayerMessage(prayerName),
      NotificationDetails(android: androidDetails),
      payload: prayerName,
    );
  }

  // ── Notification tap → open alarm screen ────────────

  static void _onNotificationTapped(NotificationResponse response) {
    final prayerName = response.payload ?? 'Prayer';

    // Guard: don't push another alarm screen if one is already showing
    if (_alarmScreenShowing != null) return;

    // Dismiss the notification via native NotificationManager
    _cancelNotificationNative(_notificationIdForPrayer(prayerName));

    // Request the alarm screen be shown
    onAlarmScreenRequested?.call(prayerName);
  }

  /// Dismiss the active notification for a prayer and mark as dismissed.
  static Future<void> dismissNotification(String prayerName) async {
    // Mark as recently dismissed so resume doesn't re-open the alarm
    _recentlyDismissed[prayerName] = DateTime.now();

    // Clear the alarm-screen-showing guard
    _alarmScreenShowing = null;

    // Cancel Flutter notification (ID 2000-2004) via native NotificationManager
    // (bypasses flutter_local_notifications v18 "Missing type parameter" bug)
    await _cancelNotificationNative(_notificationIdForPrayer(prayerName));

    // Cancel native AlarmBroadcastReceiver notification (ID 3000-3004)
    const nativeIds = {
      'Fajr': 3000, 'Dhuhr': 3001, 'Asr': 3002,
      'Maghrib': 3003, 'Isha': 3004,
    };
    final nativeId = nativeIds[prayerName];
    if (nativeId != null) {
      await _cancelNotificationNative(nativeId);
    }

    // Clear SharedPrefs so checkNativeAlarmPending doesn't re-fire
    try {
      await _alarmActivityChannel.invokeMethod('clearPendingPrayer');
    } catch (_) {}
  }

  /// Cancel a notification by ID using native Android NotificationManager.
  /// This bypasses the flutter_local_notifications v18 bug entirely.
  static Future<void> _cancelNotificationNative(int notificationId) async {
    try {
      await _alarmActivityChannel.invokeMethod('cancelNotificationById', {
        'notificationId': notificationId,
      });
    } catch (e) {
      // Fallback: try flutter_local_notifications anyway
      try {
        await _notifications.cancel(notificationId);
      } catch (_) {}
    }
  }

  // ── Helpers ─────────────────────────────────────────

  static int _alarmIdForPrayer(String name) {
    const prayerIds = {
      'Fajr': 1000,
      'Dhuhr': 1001,
      'Asr': 1002,
      'Maghrib': 1003,
      'Isha': 1004,
      'Fajr_snooze': 1005,
      'Dhuhr_snooze': 1006,
      'Asr_snooze': 1007,
      'Maghrib_snooze': 1008,
      'Isha_snooze': 1009,
    };
    return prayerIds[name] ?? (name.hashCode.abs() % 500 + 1000);
  }

  static int _notificationIdForPrayer(String name) {
    const ids = {
      'Fajr': 2000,
      'Dhuhr': 2001,
      'Asr': 2002,
      'Maghrib': 2003,
      'Isha': 2004,
    };
    return ids[name] ?? 2000;
  }

  static Future<void> _storePendingAlarm(
    int alarmId,
    String prayerName,
    String time, {
    String notifType = 'notification',
  }) async {
    try {
      final box = await HiveBoxManager.get('prayer_pending_alarms');
      await box.put(alarmId.toString(), {
        'prayer': prayerName,
        'time': time,
        'notifType': notifType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  static String _getPrayerMessage(String prayerName) {
    const messages = {
      'Fajr': 'The Fajr time has started — start your day with light ☀️',
      'Dhuhr': 'The Dhuhr time has started — pause and connect 🙏',
      'Asr': 'The Asr time has started — the angels are watching 🌤️',
      'Maghrib': 'The Maghrib time has started — a blessed sunset 🌅',
      'Isha': 'The Isha time has started — end your day in peace 🌙',
    };
    return messages[prayerName] ?? 'It\'s time for $prayerName prayer';
  }

  /// Request notification permission (Android 13+).
  static Future<bool> requestNotificationPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Check if exact alarms are permitted (Android 12+).
  static Future<bool> canScheduleExactAlarms() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? true;
  }

  /// Open battery optimization settings directly for this app.
  /// Uses native intent ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS.
  static Future<void> openBatterySettings() async {
    try {
      await _alarmActivityChannel.invokeMethod('openBatterySettings');
    } catch (_) {
      // Fallback: try permission_handler
      try {
        await openAppSettings();
      } catch (_) {}
    }
  }
}
