package com.sukoon.launcher

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat

/**
 * Background foreground service that monitors which app is in the foreground.
 * 
 * ## Normal Mode (app blocking)
 * If a blocked app is detected, launches BlockedAppActivity overlay.
 * Polls every 500ms.
 * 
 * ## ZEN MODE (maximum lockdown)
 * When Zen Mode is active, the service:
 * 1. Polls every 200ms (faster detection)
 * 2. Re-launches our app if user leaves to ANY app (not just blocked ones)
 * 3. Adds a status-bar overlay to block notification panel pull-down
 * 4. Blocks share sheets, choosers, and system UI interactions
 * 5. Only allows: our app, camera, phone/dialer
 */
class AppBlockerService : Service() {

    companion object {
        const val TAG = "AppBlockerService"
        const val CHANNEL_ID = "app_blocker_channel"
        const val NOTIFICATION_ID = 1001
        const val PREFS_NAME = "app_blocker_prefs"
        const val KEY_BLOCKED_PACKAGES = "blocked_packages"
        const val KEY_SERVICE_ENABLED = "service_enabled"
        const val KEY_ZEN_MODE = "zen_mode_active"
        const val POLL_INTERVAL_MS = 500L
        const val ZEN_POLL_INTERVAL_MS = 200L  // Faster polling in Zen Mode
        const val IDLE_POLL_INTERVAL_MS = 2000L // Slow poll when on home screen

        // Allowed packages during Zen Mode (emergency calls + camera only)
        private val ZEN_ALLOWED_PACKAGES = setOf(
            "com.android.dialer",           // Stock dialer
            "com.google.android.dialer",    // Google dialer
            "com.samsung.android.dialer",   // Samsung dialer
            "com.samsung.android.incallui", // Samsung in-call
            "com.android.incallui",         // Stock in-call
            "com.android.phone",            // Phone app
            "com.android.server.telecom",   // Telecom service
            "com.android.camera",           // Stock camera
            "com.android.camera2",          // Stock camera 2
            "com.google.android.GoogleCamera", // Google camera
            "com.samsung.android.camera",   // Samsung camera
            "com.sec.android.app.camera",   // Samsung camera alt
            "com.motorola.camera",          // Moto camera
            "com.oneplus.camera",           // OnePlus camera
            "com.oppo.camera",             // Oppo camera  
            "com.android.systemui",         // System UI (needed but monitored)
        )

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

        /** Enable/disable Zen Mode lockdown — also controls DND */
        fun setZenMode(context: Context, active: Boolean) {
            getPrefs(context).edit().putBoolean(KEY_ZEN_MODE, active).apply()
            Log.d(TAG, "Zen Mode set to: $active")
            
            // Control DND directly from service level
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.isNotificationPolicyAccessGranted) {
                    if (active) {
                        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                        Log.d(TAG, "DND ENABLED — total silence")
                    } else {
                        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                        Log.d(TAG, "DND DISABLED — notifications restored")
                    }
                } else {
                    Log.w(TAG, "DND: notification policy access NOT granted")
                }
            } catch (e: Exception) {
                Log.e(TAG, "DND control error: ${e.message}")
            }
        }

        /** Check if Zen Mode is active */
        fun isZenMode(context: Context): Boolean {
            return getPrefs(context).getBoolean(KEY_ZEN_MODE, false)
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
    private var statusBarOverlay: View? = null
    private var navBarOverlay: View? = null
    
    // Cached state — avoids SharedPreferences reads on every poll
    private var cachedIsZen = false
    private var cachedBlockedPackages: Set<String> = emptySet()
    private var cacheLastRefresh: Long = 0
    private val CACHE_TTL_MS = 3000L // Refresh cache every 3 seconds
    private var consecutiveIdlePolls = 0 // Track how long user is on home screen

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            
            // Refresh cached state periodically (not every poll)
            val now = System.currentTimeMillis()
            if (now - cacheLastRefresh > CACHE_TTL_MS) {
                cachedIsZen = isZenMode(this@AppBlockerService)
                cachedBlockedPackages = getBlockedPackages(this@AppBlockerService)
                cacheLastRefresh = now
            }
            
            checkForegroundApp()
            
            // Adaptive interval: fast during Zen, slow when idle
            val interval = when {
                cachedIsZen -> ZEN_POLL_INTERVAL_MS
                consecutiveIdlePolls > 5 -> IDLE_POLL_INTERVAL_MS // User is just on home screen
                else -> POLL_INTERVAL_MS
            }
            handler.postDelayed(this, interval)
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

        // If Zen Mode is active, enforce DND and add overlay
        if (isZenMode(this)) {
            addStatusBarOverlay()
            // Re-enforce DND on service restart (e.g. after reboot)
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (nm.isNotificationPolicyAccessGranted) {
                    nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                    Log.d(TAG, "DND re-enforced on service start")
                }
            } catch (e: Exception) {
                Log.e(TAG, "DND re-enforce error: ${e.message}")
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Service stopped")
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        removeStatusBarOverlay()
        
        // Restore DND when service stops
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.isNotificationPolicyAccessGranted) {
                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                Log.d(TAG, "DND restored on service destroy")
            }
        } catch (e: Exception) {
            Log.e(TAG, "DND restore error: ${e.message}")
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForegroundApp() {
        val isZen = cachedIsZen
        val blockedPackages = cachedBlockedPackages

        // If not in Zen Mode and no blocked packages, nothing to do
        if (!isZen && blockedPackages.isEmpty()) {
            consecutiveIdlePolls++
            return
        }

        val foregroundPackage = getForegroundPackage() ?: return

        // Don't block ourselves
        if (foregroundPackage == packageName) {
            lastBlockedPackage = null
            consecutiveIdlePolls++ // We're on home screen, slow down
            return
        }
        
        // Active app detected — reset idle counter
        consecutiveIdlePolls = 0

        if (isZen) {
            // ═══════════════════════════════════════════
            // ZEN MODE: Block EVERYTHING except allowed apps
            // ═══════════════════════════════════════════
            
            // Ensure status bar overlay is active
            if (statusBarOverlay == null) {
                addStatusBarOverlay()
            }

            // Check if this is an allowed package
            val isAllowed = ZEN_ALLOWED_PACKAGES.contains(foregroundPackage) ||
                            foregroundPackage.contains("dialer") ||
                            foregroundPackage.contains("phone") ||
                            foregroundPackage.contains("camera") ||
                            foregroundPackage.contains("incallui")

            if (!isAllowed) {
                val now = System.currentTimeMillis()
                // More aggressive throttle for Zen: 300ms (vs 1s normal)
                if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 300) {
                    return
                }

                Log.d(TAG, "ZEN BLOCK: $foregroundPackage — returning to launcher")
                lastBlockedPackage = foregroundPackage
                lastBlockTime = now

                // In Zen Mode: go straight back to our app (not to BlockedAppActivity)
                val launchIntent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                }
                startActivity(launchIntent)
            }
        } else {
            // ═══════════════════════════════════════════
            // NORMAL MODE: Only block specific packages
            // ═══════════════════════════════════════════
            if (blockedPackages.contains(foregroundPackage)) {
                val now = System.currentTimeMillis()
                if (foregroundPackage == lastBlockedPackage && (now - lastBlockTime) < 1000) {
                    return
                }
                
                Log.d(TAG, "BLOCKED: $foregroundPackage detected in foreground!")
                lastBlockedPackage = foregroundPackage
                lastBlockTime = now

                val blockIntent = Intent(this, BlockedAppActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra("blocked_package", foregroundPackage)
                }
                startActivity(blockIntent)
            } else {
                if (lastBlockedPackage != null) {
                    lastBlockedPackage = null
                }
            }
        }
    }

    /**
     * Add an invisible overlay at the top of the screen to intercept
     * notification panel swipe-down gesture.
     * Requires SYSTEM_ALERT_WINDOW permission.
     */
    private fun addStatusBarOverlay() {
        if (statusBarOverlay != null) return  // Already added

        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Cannot add overlays: SYSTEM_ALERT_WINDOW not granted")
            return
        }

        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ERROR
            }

            // ─── TOP OVERLAY: Block notification shade pull-down ───
            statusBarOverlay = View(this).apply {
                setBackgroundColor(0x01000000) // Nearly invisible
                isClickable = true  // Consumes touch events
                isFocusable = false
            }

            val topParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                150,  // Tall enough to catch swipe-down gesture
                overlayType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 0
                y = 0
            }

            wm.addView(statusBarOverlay, topParams)
            Log.d(TAG, "TOP overlay ADDED (150px) — notification shade blocked")

            // ─── BOTTOM OVERLAY: Block recent apps / home swipe-up ───
            navBarOverlay = View(this).apply {
                setBackgroundColor(0x01000000) // Nearly invisible
                isClickable = true  // Consumes touch events
                isFocusable = false
            }

            val bottomParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                150,  // Tall enough to catch swipe-up gesture
                overlayType,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.BOTTOM or Gravity.START
                x = 0
                y = 0
            }

            wm.addView(navBarOverlay, bottomParams)
            Log.d(TAG, "BOTTOM overlay ADDED (150px) — recent apps gesture blocked")

        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlays: ${e.message}")
        }
    }

    /**
     * Remove all overlays when Zen Mode ends.
     */
    private fun removeStatusBarOverlay() {
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        statusBarOverlay?.let { overlay ->
            try {
                wm.removeView(overlay)
                Log.d(TAG, "TOP overlay REMOVED")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing top overlay: ${e.message}")
            }
        }
        statusBarOverlay = null

        navBarOverlay?.let { overlay ->
            try {
                wm.removeView(overlay)
                Log.d(TAG, "BOTTOM overlay REMOVED")
            } catch (e: Exception) {
                Log.e(TAG, "Error removing bottom overlay: ${e.message}")
            }
        }
        navBarOverlay = null
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
            val usageEvents = usageStatsManager.queryEvents(now - 5000, now)
            
            var lastForegroundPackage: String? = null
            var lastTimestamp: Long = 0

            val event = android.app.usage.UsageEvents.Event()
            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
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
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps app blocker active in the background"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val isZen = isZenMode(this)
        val blockedCount = getBlockedPackages(this).size
        
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (isZen) "🧘 Zen Mode Active" else "☪️ Focus Mode Active"
        val text = if (isZen) "Phone locked · Put it down & enjoy life" else "$blockedCount apps blocked · Stay focused"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
}
