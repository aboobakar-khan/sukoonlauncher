package com.sukoon.launcher

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Device Admin Receiver for Sukoon Launcher.
 * Required to call DevicePolicyManager.lockNow() for the double-tap lock screen feature.
 * User must grant Device Admin permission once from Settings → Security → Device Admin Apps.
 */
class SukoonDeviceAdmin : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }
}
