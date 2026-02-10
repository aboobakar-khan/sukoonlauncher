package com.example.minimalist_app

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import android.view.View
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.minimalist_app/launcher"
    private val APP_SETTINGS_CHANNEL = "app_settings"
    private val USAGE_STATS_CHANNEL = "com.minimalist.launcher/usage_stats"
    private val BLOCKER_CHANNEL = "com.minimalist.launcher/app_blocker"
    private val DND_CHANNEL = "com.minimalist.launcher/dnd"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ── App Blocker Service channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    try {
                        AppBlockerService.start(this)
                        Log.d("AppBlocker", "Service started from Flutter")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Could not start blocker service: ${e.message}", null)
                    }
                }
                "stopService" -> {
                    try {
                        AppBlockerService.stop(this)
                        Log.d("AppBlocker", "Service stopped from Flutter")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_ERROR", "Could not stop blocker service: ${e.message}", null)
                    }
                }
                "updateBlockedPackages" -> {
                    try {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        AppBlockerService.updateBlockedPackages(this, packages.toSet())
                        
                        // If service is running and list is now empty, stop it
                        if (packages.isEmpty()) {
                            AppBlockerService.stop(this)
                        } else if (!AppBlockerService.isEnabled(this)) {
                            // Auto-start service if we have blocked packages
                            AppBlockerService.start(this)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", "Could not update blocked packages: ${e.message}", null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(AppBlockerService.isEnabled(this))
                }
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open usage access settings", null)
                    }
                }
                "hasNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        result.success(
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                                PackageManager.PERMISSION_GRANTED
                        )
                    } else {
                        result.success(true) // Not needed pre-Android 13
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(
                            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                // ── Zen Mode Methods ──
                "setZenMode" -> {
                    try {
                        val active = call.argument<Boolean>("active") ?: false
                        AppBlockerService.setZenMode(this, active)
                        
                        if (active) {
                            // Ensure service is running for Zen Mode
                            if (!AppBlockerService.isEnabled(this)) {
                                AppBlockerService.start(this)
                            }
                            // Enable lock screen bypass
                            enableZenLockScreen()
                        } else {
                            // Disable lock screen bypass
                            disableZenLockScreen()
                        }
                        
                        Log.d("AppBlocker", "Zen Mode set to: $active")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ZEN_ERROR", "Failed to set Zen Mode: ${e.message}", null)
                    }
                }
                "enableZenLockScreen" -> {
                    try {
                        enableZenLockScreen()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", "Failed to enable lock screen mode: ${e.message}", null)
                    }
                }
                "disableZenLockScreen" -> {
                    try {
                        disableZenLockScreen()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LOCK_ERROR", "Failed to disable lock screen mode: ${e.message}", null)
                    }
                }
                "enterFullImmersive" -> {
                    try {
                        enterFullImmersive()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMMERSIVE_ERROR", e.message, null)
                    }
                }
                "exitFullImmersive" -> {
                    try {
                        exitFullImmersive()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("IMMERSIVE_ERROR", e.message, null)
                    }
                }
                "temporaryUnpin" -> {
                    // Temporarily unpin screen for emergency call / camera
                    // onResume will re-pin when user returns
                    try {
                        stopLockTask()
                        isZenPinned = false
                        Log.d("ZenLock", "Temporarily UNPINNED for allowed action")
                        result.success(true)
                    } catch (e: Exception) {
                        isZenPinned = false
                        result.success(true) // Don't block the action
                    }
                }
                "openCamera" -> {
                    try {
                        // Unpin first
                        try { stopLockTask(); isZenPinned = false } catch (_: Exception) { isZenPinned = false }
                        
                        // Try to open camera with intent
                        val cameraIntent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE)
                        if (cameraIntent.resolveActivity(packageManager) != null) {
                            startActivity(cameraIntent)
                            result.success(true)
                        } else {
                            // Fallback: try known camera packages
                            val cameraPackages = listOf(
                                "com.android.camera",
                                "com.android.camera2", 
                                "com.google.android.GoogleCamera",
                                "com.samsung.android.camera",
                                "com.sec.android.app.camera",
                                "com.oneplus.camera",
                                "com.oppo.camera",
                                "com.coloros.camera",
                                "com.motorola.camera",
                                "com.realme.camera"
                            )
                            var launched = false
                            for (pkg in cameraPackages) {
                                val intent = packageManager.getLaunchIntentForPackage(pkg)
                                if (intent != null) {
                                    startActivity(intent)
                                    launched = true
                                    break
                                }
                            }
                            result.success(launched)
                        }
                    } catch (e: Exception) {
                        result.error("CAMERA_ERROR", e.message, null)
                    }
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open overlay settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Launcher settings channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openHomeLauncherSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open home settings: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Usage Stats channel for Screen Time Analytics
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_STATS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open usage access settings", null)
                    }
                }
                "getUsageStats" -> {
                    try {
                        val startTime = call.argument<Long>("startTime") ?: 0L
                        val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                        
                        if (!hasUsageStatsPermission()) {
                            result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
                            return@setMethodCallHandler
                        }
                        
                        val usageStats = getUsageStats(startTime, endTime)
                        result.success(usageStats)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get usage stats: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // App settings channel for uninstall
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_SETTINGS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "uninstallApp" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val intent = Intent(Intent.ACTION_DELETE)
                            intent.data = Uri.parse("package:$packageName")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("UNAVAILABLE", "No app found to handle uninstall", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "Package name is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not uninstall app: ${e.message}", null)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val packageName = call.argument<String>("packageName")
                        if (packageName != null) {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("UNAVAILABLE", "No app found to handle app settings", null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENT", "Package name is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open app settings: ${e.message}", null)
                    }
                }
                "launchGooglePay" -> {
                    try {
                        val packageNames = listOf(
                            "com.google.android.apps.nbu.paisa.user",
                            "com.google.android.apps.pay",
                            "com.google.android.apps.walletnfchost",
                            "com.google.android.gms"
                        )
                        
                        var launched = false
                        for (packageName in packageNames) {
                            try {
                                val intent = packageManager.getLaunchIntentForPackage(packageName)
                                if (intent != null) {
                                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                    startActivity(intent)
                                    launched = true
                                    break
                                }
                            } catch (e: Exception) {
                                // Try next package name
                            }
                        }
                        
                        if (!launched) {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW)
                                intent.data = Uri.parse("https://pay.google.com")
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                                launched = true
                            } catch (e: Exception) {
                                // Fallback failed
                            }
                        }
                        
                        if (launched) {
                            result.success(true)
                        } else {
                            result.error("UNAVAILABLE", "Google Pay app not found", null)
                        }
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not launch Google Pay: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // ── DND (Do Not Disturb) channel ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DND_CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            when (call.method) {
                "enableDND" -> {
                    try {
                        if (notificationManager.isNotificationPolicyAccessGranted) {
                            notificationManager.setInterruptionFilter(
                                NotificationManager.INTERRUPTION_FILTER_NONE  // Total silence
                            )
                            Log.d("DND", "DND enabled (total silence)")
                            result.success(true)
                        } else {
                            result.error("PERMISSION_DENIED", "DND permission not granted", null)
                        }
                    } catch (e: Exception) {
                        result.error("DND_ERROR", "Failed to enable DND: ${e.message}", null)
                    }
                }
                "disableDND" -> {
                    try {
                        if (notificationManager.isNotificationPolicyAccessGranted) {
                            notificationManager.setInterruptionFilter(
                                NotificationManager.INTERRUPTION_FILTER_ALL  // All notifications
                            )
                            Log.d("DND", "DND disabled (all sounds restored)")
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("DND_ERROR", "Failed to disable DND: ${e.message}", null)
                    }
                }
                "hasDndPermission" -> {
                    result.success(notificationManager.isNotificationPolicyAccessGranted)
                }
                "requestDndPermission" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not open DND settings: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun getUsageStats(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        
        // Use INTERVAL_BEST for more accurate daily data
        // INTERVAL_DAILY can aggregate incorrectly across midnight
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_BEST,
            startTime,
            endTime
        )
        
        val result = mutableListOf<Map<String, Any>>()
        val pm = packageManager
        
        for (usageStat in stats) {
            if (usageStat.totalTimeInForeground > 0) {
                val appName = try {
                    pm.getApplicationLabel(
                        pm.getApplicationInfo(usageStat.packageName, 0)
                    ).toString()
                } catch (e: PackageManager.NameNotFoundException) {
                    usageStat.packageName.split(".").lastOrNull() ?: usageStat.packageName
                }
                
                result.add(mapOf(
                    "packageName" to usageStat.packageName,
                    "appName" to appName,
                    "usageTime" to usageStat.totalTimeInForeground,
                    "lastUsed" to usageStat.lastTimeUsed
                ))
            }
        }
        
        return result.sortedByDescending { it["usageTime"] as Long }
    }

    // ════════════════════════════════════════════════════════════════
    // ZEN MODE: Lock Screen & Immersive Mode Control
    // ════════════════════════════════════════════════════════════════

    private var isZenPinned = false  // Track pinning state to avoid repeated pin/toast

    /**
     * Show Zen Mode screen OVER the lock screen.
     * Called once when Zen Mode is activated.
     */
    private fun enableZenLockScreen() {
        runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    // Show our app over lock screen (no need for setTurnScreenOn —
                    // that causes screen to auto-wake after power button)
                    setShowWhenLocked(true)
                    // Do NOT call requestDismissKeyguard — it triggers PIN dialog
                } else {
                    @Suppress("DEPRECATION")
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    )
                }
                
                // Pin screen ONLY if not already pinned (avoids "app pinned" toast spam)
                if (!isZenPinned) {
                    try {
                        startLockTask()
                        isZenPinned = true
                        Log.d("ZenLock", "Screen PINNED — system navigation blocked")
                    } catch (e: Exception) {
                        Log.w("ZenLock", "Screen pinning failed: ${e.message}")
                    }
                }
                
                // Immersive mode
                enterFullImmersive()
                
                Log.d("ZenLock", "Lock screen bypass ENABLED")
            } catch (e: Exception) {
                Log.e("ZenLock", "Error enabling lock screen mode: ${e.message}")
            }
        }
    }

    /**
     * Restore normal lock screen behavior when Zen Mode ends.
     */
    private fun disableZenLockScreen() {
        runOnUiThread {
            try {
                // Unpin screen
                if (isZenPinned) {
                    try {
                        stopLockTask()
                        isZenPinned = false
                        Log.d("ZenLock", "Screen UNPINNED")
                    } catch (e: Exception) {
                        Log.w("ZenLock", "Unpin error: ${e.message}")
                    }
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(false)
                } else {
                    @Suppress("DEPRECATION")
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                    )
                }
                
                exitFullImmersive()
                
                Log.d("ZenLock", "Lock screen bypass DISABLED")
            } catch (e: Exception) {
                Log.e("ZenLock", "Error disabling lock screen mode: ${e.message}")
            }
        }
    }

    /**
     * Full immersive mode — hides status bar, navigation bar,
     * and blocks all swipe gestures (notification bar, recent apps).
     */
    private fun enterFullImmersive() {
        runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.let { controller ->
                        controller.hide(
                            android.view.WindowInsets.Type.statusBars() or
                            android.view.WindowInsets.Type.navigationBars()
                        )
                        controller.systemBarsBehavior = 
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
                Log.e("ZenLock", "Immersive mode error: ${e.message}")
            }
        }
    }

    /**
     * Exit immersive mode — restore normal status/nav bars.
     */
    private fun exitFullImmersive() {
        runOnUiThread {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.let { controller ->
                        controller.show(
                            android.view.WindowInsets.Type.statusBars() or
                            android.view.WindowInsets.Type.navigationBars()
                        )
                    }
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
                }
            } catch (e: Exception) {
                Log.e("ZenLock", "Exit immersive error: ${e.message}")
            }
        }
    }

    /**
     * On resume: only re-enforce immersive mode (lightweight).
     * DO NOT re-call enableZenLockScreen — that would re-trigger
     * PIN dialog and "app pinned" toast.
     */
    override fun onResume() {
        super.onResume()
        if (AppBlockerService.isZenMode(this)) {
            // Just re-enforce immersive (screen pinning persists across resume)
            enterFullImmersive()
            
            // Re-pin only if we lost pinning (e.g., after temporary unpin for camera/call)
            if (!isZenPinned) {
                try {
                    startLockTask()
                    isZenPinned = true
                    Log.d("ZenLock", "Re-pinned on resume")
                } catch (e: Exception) {
                    Log.w("ZenLock", "Re-pin failed: ${e.message}")
                }
            }
        }
    }

    // Removed onPause re-launch — it was causing screen wake-up loop.
    // The AppBlockerService already handles bringing user back.

    /**
     * Block back button during Zen Mode.
     */
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (AppBlockerService.isZenMode(this)) {
            // Do nothing — block exit
            return
        }
        super.onBackPressed()
    }
}

