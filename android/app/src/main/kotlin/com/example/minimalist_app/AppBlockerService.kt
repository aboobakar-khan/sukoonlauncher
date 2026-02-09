package com.example.minimalist_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Background foreground service that monitors which app is in the foreground.
 * If a blocked app is detected, it immediately launches BlockedAppActivity
 * which covers the blocked app — blocking access from notifications,
 * recent apps, and any other launch vector.
 *
 * Uses UsageStatsManager (already permitted) to poll foreground app every 500ms.
 */
class AppBlockerService : Service() {

    companion object {
        const val TAG = "AppBlockerService"
        const val CHANNEL_ID = "app_blocker_channel"
        const val NOTIFICATION_ID = 1001
        const val PREFS_NAME = "app_blocker_prefs"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val POLL_INTERVAL_MS = 500L

        fun getPrefs(context: Context): SharedPreferences {
            return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }

        /** Update the blocked packages list from Flutter side */
        fun updateBlockedPackages(context: Context, packages: Set<String>) {
            getPrefs(context).edit()
                .putStringSet(KEY_BLOCKED_PACKAGES, packages)
                .apply()
            Log.d(TAG, "Updated blocked packages: ${packages.size} apps")
        }

        /** Get currently blocked packages */
        fun getBlockedPackages(context: Context): Set<String> {
            return getPrefs(context).getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet()
        }

        /** Start the blocker service */
        fun start(context: Context) {
            getPrefs(context).edit().putBoolean(KEY_SERVICE_ENABLED, true).apply()
            val intent = Intent(context, AppBlockerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** Stop the blocker service */
        fun stop(context: Context) {
            getPrefs(context).edit().putBoolean(KEY_SERVICE_ENABLED, false).apply()
            context.stopService(Intent(context, AppBlockerService::class.java))
        }

        /** Check if service should be running */
        fun isEnabled(context: Context): Boolean {
            return getPrefs(context).getBoolean(KEY_SERVICE_ENABLED, false)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private var lastBlockedPackage: String? = null
    private var lastBlockTime: Long = 0

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        startForeground(NOTIFICATION_ID, buildNotification())
        isRunning = true
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Service stopped")
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundApp() {
        val blockedPackages = getBlockedPackages(this)
        if (blockedPackages.isEmpty()) return

        val foregroundPackage = getForegroundPackage() ?: return

        // Don't block ourselves
        if (foregroundPackage == packageName) {
            lastBlockedPackage = null
            return
        }

        // Don't block the blocker overlay itself
        if (foregroundPackage == packageName) return

        if (blockedPackages.contains(foregroundPackage)) {
            val now = System.currentTimeMillis()
            // Throttle: don't re-block same app within 1 second (avoid flickering)
            if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 1000) {
                return
            }
            
            Log.d(TAG, "BLOCKED: $foregroundPackage detected in foreground!")
            lastBlockedPackage = foregroundPackage
            lastBlockTime = now

            // Launch the blocking overlay
            val blockIntent = Intent(this, BlockedAppActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("blocked_package", foregroundPackage)
            }
            startActivity(blockIntent)
        } else {
            // Not a blocked app — reset tracker
            if (lastBlockedPackage != null) {
                lastBlockedPackage = null
            }
        }
    }

    /**
     * Get the foreground package using UsageStatsManager.
     * This is the most reliable method on Android 5.0+ and doesn't
     * require AccessibilityService.
     */
    private fun getForegroundPackage(): String? {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            // Query last 5 seconds of usage events
            val usageEvents = usageStatsManager.queryEvents(now - 5000, now)
            
            var lastForegroundPackage: String? = null
            var lastTimestamp: Long = 0

            val event = android.app.usage.UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                // ACTIVITY_RESUMED = moved to foreground (API 29+)
                // MOVE_TO_FOREGROUND = older constant
                if (event.eventType == android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == 1 /* MOVE_TO_FOREGROUND */) {
                    if (event.timeStamp > lastTimestamp) {
                        lastTimestamp = event.timeStamp
                        lastForegroundPackage = event.packageName
                    }
                }
            }
            return lastForegroundPackage
        } catch (e: Exception) {
            Log.e(TAG, "Error getting foreground package: ${e.message}")
            return null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker",
                NotificationManager.IMPORTANCE_LOW // Low = no sound, shows in shade
            ).apply {
                description = "Keeps app blocker active in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val blockedCount = getBlockedPackages(this).size
        
        // Tap notification → open our launcher
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🐪 Focus Mode Active")
            .setContentText("$blockedCount apps blocked · Stay focused")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
