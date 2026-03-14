package com.sukoon.launcher

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.WindowManager

/**
 * ZenLockScreenActivity — shown over the Android lock screen during Zen Mode.
 *
 * When Zen Mode is active and the user presses the power button to wake the phone,
 * Android normally shows the keyguard (PIN/pattern/biometrics). Instead, this
 * Activity appears on top of the keyguard — the user sees only the Zen Mode screen,
 * cannot unlock, and cannot access anything until the Zen timer expires.
 *
 * How it works:
 *  1. AppBlockerService calls ZenLockScreenActivity.show() when Zen is active.
 *  2. This Activity uses FLAG_SHOW_WHEN_LOCKED (no FLAG_DISMISS_KEYGUARD) so it
 *     sits on top of the keyguard — the lock screen is still there underneath.
 *  3. The screen is kept on and the back/home/recents buttons are all blocked.
 *  4. A BroadcastReceiver listens for ACTION_SCREEN_ON to auto-show this Activity
 *     every time the user wakes the phone during a Zen session.
 *  5. When the Zen timer expires, MainActivity calls ZenLockScreenActivity.dismiss()
 *     which finishes this Activity and un-registers the screen-on listener.
 *
 * The actual Zen countdown UI is displayed inside MainActivity (Flutter). This
 * Activity is just a transparent native layer that overrides the keyguard — it
 * immediately forwards to MainActivity so Flutter can render on top of it.
 */
class ZenLockScreenActivity : Activity() {

    companion object {
        private const val TAG = "ZenLockScreen"
        const val ACTION_DISMISS = "com.sukoon.launcher.ZEN_DISMISS"
        private const val PREFS_NAME = "zen_lock_prefs"
        private const val KEY_ZEN_ACTIVE = "zen_lock_active"

        /** Called by MainActivity/Flutter when Zen Mode starts. */
        fun show(context: Context) {
            markActive(context, true)
            val intent = Intent(context, ZenLockScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            context.startActivity(intent)
            Log.d(TAG, "ZenLockScreenActivity started")
        }

        /** Called when Zen Mode ends — dismisses the lock-screen overlay. */
        fun dismiss(context: Context) {
            markActive(context, false)
            // Send broadcast so any live instance of this Activity finishes itself.
            val intent = Intent(ACTION_DISMISS).apply {
                setPackage(context.packageName)
            }
            context.sendBroadcast(intent)
            Log.d(TAG, "ZenLockScreen dismiss broadcast sent")
        }

        /** Returns true if Zen lock screen should be showing. */
        fun isActive(context: Context): Boolean {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_ZEN_ACTIVE, false)
        }

        private fun markActive(context: Context, active: Boolean) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_ZEN_ACTIVE, active).apply()
        }
    }

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_DISMISS) {
                Log.d(TAG, "Dismiss broadcast received — finishing ZenLockScreenActivity")
                finishAndRemoveTask()
            }
        }
    }

    // Receiver that re-launches this Activity every time the screen turns ON
    // while Zen Mode is still active.
    private val screenOnReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_ON) {
                if (isActive(context)) {
                    Log.d(TAG, "Screen ON during Zen — re-showing ZenLockScreen")
                    // Small delay so the keyguard can appear first, then we overlay it
                    Handler(Looper.getMainLooper()).postDelayed({
                        show(context)
                    }, 150)
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        applyWindowFlags()
        super.onCreate(savedInstanceState)

        // Lock to portrait on phones; Android 16+ may override on large screens (expected)
        val isLargeScreen = (resources.configuration.screenLayout and
                Configuration.SCREENLAYOUT_SIZE_MASK) >= Configuration.SCREENLAYOUT_SIZE_LARGE
        if (!isLargeScreen) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }

        // Full immersive — hide status bar and navigation bar
        hideSystemUI()

        // Register dismiss receiver
        val dismissFilter = IntentFilter(ACTION_DISMISS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissReceiver, dismissFilter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(dismissReceiver, dismissFilter)
        }

        // Register screen-on receiver (so every power-button wake shows Zen screen)
        val screenFilter = IntentFilter(Intent.ACTION_SCREEN_ON)
        registerReceiver(screenOnReceiver, screenFilter)

        Log.d(TAG, "ZenLockScreenActivity created — showing over lock screen")

        // Forward immediately to MainActivity so Flutter renders the Zen countdown UI
        // on top of this Activity (which is already over the keyguard).
        forwardToMainActivity()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Re-enforce flags if the Activity is brought back to the top
        applyWindowFlags()
        hideSystemUI()
    }

    override fun onResume() {
        super.onResume()
        // Re-check: if Zen Mode has ended (e.g. timer expired), finish ourselves
        if (!isActive(this)) {
            Log.d(TAG, "Zen no longer active on resume — finishing")
            finishAndRemoveTask()
            return
        }
        hideSystemUI()
        // Re-forward to MainActivity if it somehow lost focus
        forwardToMainActivity()
    }

    override fun onDestroy() {
        try { unregisterReceiver(dismissReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(screenOnReceiver) } catch (_: Exception) {}
        super.onDestroy()
    }

    /** Block back button — user cannot exit during Zen Mode. */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Do nothing during Zen Mode
        Log.d(TAG, "Back blocked during Zen Mode")
    }

    // ─── Private helpers ──────────────────────────────────────────────────────

    private fun applyWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Show over the keyguard WITHOUT dismissing it.
            // The lock screen is still "underneath" — just not visible.
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            // Intentionally NOT calling requestDismissKeyguard — we want to
            // stay ON TOP of the lock screen, not unlock it.
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD.inv().and(0) // intentionally not set
        )
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun hideSystemUI() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.insetsController?.let { ctrl ->
                    ctrl.hide(
                        android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars()
                    )
                    ctrl.systemBarsBehavior =
                        android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                }
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    or View.SYSTEM_UI_FLAG_FULLSCREEN
                    or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "hideSystemUI error: ${e.message}")
        }
    }

    private fun forwardToMainActivity() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra("zen_lock_active", true)
        }
        startActivity(intent)
    }
}
