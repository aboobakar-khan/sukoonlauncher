package com.sukoon.launcher

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * AlarmBroadcastReceiver — the single entry-point for ALL prayer alarm firing.
 *
 * Triggered by Android's AlarmManager (set natively via MethodChannel from Flutter).
 * This runs entirely in native code — no Dart isolate, no platform channel latency.
 *
 * On fire:
 *  1. Writes the prayer name to SharedPreferences (Flutter reads on resume).
 *  2. Starts AlarmActivity to wake + unlock the screen immediately.
 *  3. Shows a fullScreenIntent notification as a second-layer guarantee.
 *
 * Scheduling: Flutter calls 'scheduleNativeAlarm' on the alarm_activity channel.
 * MainActivity schedules via AlarmManagerCompat.setExactAndAllowWhileIdle().
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmBroadcastReceiver"
        const val CHANNEL_ID = "prayer_alarm_wake"
        const val CHANNEL_NAME = "Prayer Alarm Wake"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        private const val ACTION = "com.sukoon.launcher.PRAYER_ALARM"

        // Request codes for PendingIntents — one per prayer
        val prayerRequestCodes = mapOf(
            "Fajr"    to 5000,
            "Dhuhr"   to 5001,
            "Asr"     to 5002,
            "Maghrib" to 5003,
            "Isha"    to 5004,
        )
        val prayerNotificationIds = mapOf(
            "Fajr"    to 3000,
            "Dhuhr"   to 3001,
            "Asr"     to 3002,
            "Maghrib" to 3003,
            "Isha"    to 3004,
        )

        /** Schedule an exact alarm that fires this receiver. */
        fun scheduleAlarm(context: Context, prayerName: String, triggerAtMillis: Long) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context, prayerName)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (am.canScheduleExactAlarms()) {
                    am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pi), pi)
                } else {
                    // Fallback for devices that denied SCHEDULE_EXACT_ALARM
                    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, pi), pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
            Log.d(TAG, "Native alarm scheduled for $prayerName at $triggerAtMillis")
        }

        /** Cancel a previously scheduled alarm for this prayer. */
        fun cancelAlarm(context: Context, prayerName: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.cancel(buildPendingIntent(context, prayerName))
            Log.d(TAG, "Native alarm cancelled for $prayerName")
        }

        private fun buildPendingIntent(context: Context, prayerName: String): PendingIntent {
            val intent = Intent(context, AlarmBroadcastReceiver::class.java).apply {
                action = ACTION
                putExtra(EXTRA_PRAYER_NAME, prayerName)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else PendingIntent.FLAG_UPDATE_CURRENT

            return PendingIntent.getBroadcast(
                context,
                prayerRequestCodes[prayerName] ?: 5000,
                intent,
                flags
            )
        }

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(AlarmActivity.PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
        Log.d(TAG, "🕌 Native alarm fired for: $prayerName")

        // ① Write to SharedPreferences FIRST so Flutter sees it on any resume
        prefs(context).edit()
            .putString(AlarmActivity.PREFS_KEY_PRAYER, prayerName)
            .apply()

        // ② Ensure notification channel exists
        ensureNotificationChannel(context)

        // ③ Show fullScreenIntent notification — guaranteed layer for lock screen
        showWakeNotification(context, prayerName)

        // ④ If the screen is ON and device is UNLOCKED, also start AlarmActivity
        //    directly. Android's fullScreenIntent only auto-launches the activity
        //    when the screen is off or the keyguard is showing. On an unlocked,
        //    active screen it merely posts a heads-up notification. By also
        //    calling startActivity here we ensure the alarm page opens immediately
        //    in BOTH scenarios (locked + unlocked).
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            val screenOn = pm.isInteractive
            val locked = km.isKeyguardLocked

            if (screenOn && !locked) {
                Log.d(TAG, "Screen ON + unlocked → starting AlarmActivity directly")
                val activityIntent = AlarmActivity.createIntent(context, prayerName)
                activityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(activityIntent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity failed (will rely on notification): ${e.message}")
        }
    }

    // ── Notification helpers ──────────────────────────────────────────────

    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID, CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Full-screen alarm for Salah times"
                    enableVibration(true)
                    setShowBadge(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    private fun showWakeNotification(context: Context, prayerName: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Both content tap and fullScreen tap go through AlarmActivity → MainActivity
        val activityIntent = AlarmActivity.createIntent(context, prayerName)
        val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

        val contentPi = PendingIntent.getActivity(
            context, prayerNotificationIds[prayerName] ?: 3000, activityIntent, piFlags)
        val fullScreenPi = PendingIntent.getActivity(
            context, (prayerNotificationIds[prayerName] ?: 3000) + 100, activityIntent, piFlags)

        val title = "🕌 Time for $prayerName"
        val body = getPrayerMessage(prayerName)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(false)
            .setTimeoutAfter(90_000L) // Auto-dismiss after 90 seconds — mirrors auto-close timer
            .setContentIntent(contentPi)
            .setFullScreenIntent(fullScreenPi, true)
            .build()

        nm.notify(prayerNotificationIds[prayerName] ?: 3000, notification)
    }

    private fun getPrayerMessage(prayerName: String): String = when (prayerName) {
        "Fajr"    -> "The Fajr time has started — start your day with light ☀️"
        "Dhuhr"   -> "The Dhuhr time has started — pause and connect 🙏"
        "Asr"     -> "The Asr time has started — the angels are watching 🌤️"
        "Maghrib" -> "The Maghrib time has started — a blessed sunset 🌅"
        "Isha"    -> "The Isha time has started — end your day in peace 🌙"
        else      -> "It's time for $prayerName prayer"
    }
}
