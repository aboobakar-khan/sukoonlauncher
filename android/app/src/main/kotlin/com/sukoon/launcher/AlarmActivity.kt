package com.sukoon.launcher

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager

/**
 * AlarmActivity — native trampoline that wakes the screen and shows the alarm
 * DIRECTLY OVER the lock screen — exactly like the Android stock alarm clock.
 *
 * KEY DESIGN: We intentionally do NOT call requestDismissKeyguard / FLAG_DISMISS_KEYGUARD.
 * Instead we use setShowWhenLocked(true) + setTurnScreenOn(true) so the alarm
 * appears over the keyguard without asking the user to unlock first.
 * MainActivity inherits the same flags via the Intent extra, so the Flutter
 * alarm screen is also shown over the lock screen.
 *
 * Flow:
 *   AlarmBroadcastReceiver (fullScreenIntent)
 *     → AlarmActivity (wakes screen, shows over lock screen, no keyguard dismiss)
 *       → MainActivity (inherits flags, Flutter shows alarm UI over lock screen)
 *         → user taps "Prayed / Snooze / Dismiss" → alarm cleared
 */
class AlarmActivity : Activity() {

    companion object {
        private const val TAG = "AlarmActivity"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val PREFS_NAME = "prayer_alarm_prefs"
        const val PREFS_KEY_PRAYER = "pending_prayer_name"

        fun createIntent(context: Context, prayerName: String): Intent =
            Intent(context, AlarmActivity::class.java).apply {
                putExtra(EXTRA_PRAYER_NAME, prayerName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Apply wake/lock-screen-overlay flags BEFORE super.onCreate so the
        // window is configured before any drawing happens.
        applyWakeFlags()
        super.onCreate(savedInstanceState)

        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "Prayer"
        Log.d(TAG, "AlarmActivity fired for: $prayerName — showing over lock screen")

        // Persist to SharedPreferences so Flutter reads it on cold/warm start.
        prefs().edit().putString(PREFS_KEY_PRAYER, prayerName).apply()

        // Launch MainActivity immediately — it will also show over the lock screen
        // because we pass the prayer name extra and it calls applyAlarmWakeFlags().
        // Do NOT call requestDismissKeyguard — that triggers PIN/pattern/fingerprint
        // and is the root cause of "user has to unlock first" behaviour.
        launchMainActivity(prayerName)
    }

    private fun launchMainActivity(prayerName: String) {
        val mainIntent = Intent(this, MainActivity::class.java).apply {
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        }
        startActivity(mainIntent)

        // Keep this Activity alive a moment so the wake flags are not dropped
        // before MainActivity's window is fully ready (Samsung / Xiaomi quirk).
        Handler(Looper.getMainLooper()).postDelayed({ finish() }, 2000)
    }

    private fun applyWakeFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Show this window on top of the lock screen and turn the screen on —
            // the same API the AOSP DeskClock app uses.
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            // Intentionally NOT calling requestDismissKeyguard here.
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                // No FLAG_DISMISS_KEYGUARD — alarm must appear over the lock screen
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
