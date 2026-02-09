package com.example.minimalist_app

import android.app.AppOpsManager
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
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.minimalist_app/launcher"
    private val APP_SETTINGS_CHANNEL = "app_settings"
    private val USAGE_STATS_CHANNEL = "com.minimalist.launcher/usage_stats"
    private val BLOCKER_CHANNEL = "com.minimalist.launcher/app_blocker"

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
}

