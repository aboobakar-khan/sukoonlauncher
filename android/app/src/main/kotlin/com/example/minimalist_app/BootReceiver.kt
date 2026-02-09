package com.example.minimalist_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Restarts the AppBlockerService after device reboot,
 * if it was enabled before the reboot.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Boot completed, checking blocker service...")
            
            val blockedPackages = AppBlockerService.getBlockedPackages(context)
            val wasEnabled = AppBlockerService.isEnabled(context)
            
            if (wasEnabled && blockedPackages.isNotEmpty()) {
                Log.d("BootReceiver", "Restarting blocker service with ${blockedPackages.size} blocked apps")
                AppBlockerService.start(context)
            }
        }
    }
}
