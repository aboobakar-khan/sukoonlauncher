package com.example.minimalist_app

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Full-screen overlay that blocks access to a blocked app.
 * Launched by AppBlockerService when it detects a blocked app in the foreground.
 * 
 * This Activity sits on top of the blocked app and pressing back
 * goes to the home screen (our launcher), not back to the blocked app.
 */
class BlockedAppActivity : Activity() {

    companion object {
        const val TAG = "BlockedAppActivity"
    }

    private var blockedPackage: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        blockedPackage = intent?.getStringExtra("blocked_package")
        Log.d(TAG, "Blocking overlay shown for: $blockedPackage")

        // Make it full screen, cover everything
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)

        // Get app name
        val appName = try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(blockedPackage ?: "", 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            blockedPackage?.split(".")?.lastOrNull() ?: "App"
        }

        // Build the blocking UI programmatically (no XML needed)
        val root = FrameLayout(this).apply {
            setBackgroundColor(0xFF0A0A0A.toInt()) // Near-black background
            isClickable = true  // Consume all touches
            isFocusable = true
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(80, 0, 80, 0)
        }

        // Shield icon
        val icon = TextView(this).apply {
            text = "🛡️"
            textSize = 64f
            gravity = Gravity.CENTER
        }
        content.addView(icon)

        // Spacing
        content.addView(spacer(48))

        // "App Blocked" title
        val title = TextView(this).apply {
            text = "App Blocked"
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            letterSpacing = 0.02f
            paint.isFakeBoldText = true
        }
        content.addView(title)

        // Spacing
        content.addView(spacer(16))

        // App name
        val subtitle = TextView(this).apply {
            text = "$appName is blocked right now"
            textSize = 16f
            setTextColor(0x99FFFFFF.toInt()) // White 60%
            gravity = Gravity.CENTER
        }
        content.addView(subtitle)

        // Spacing
        content.addView(spacer(12))

        // Motivational message
        val message = TextView(this).apply {
            text = "Stay focused! 🐪\nYou're doing great."
            textSize = 14f
            setTextColor(0x66FFFFFF.toInt()) // White 40%
            gravity = Gravity.CENTER
            setLineSpacing(8f, 1f)
        }
        content.addView(message)

        // Spacing
        content.addView(spacer(48))

        // "Go Home" button
        val goHomeBtn = TextView(this).apply {
            text = "← Go Home"
            textSize = 16f
            setTextColor(0xFFC2A366.toInt()) // Gold accent
            gravity = Gravity.CENTER
            setPadding(64, 32, 64, 32)
            setBackgroundColor(0x1AC2A366.toInt()) // Gold 10%
            setOnClickListener { goHome() }
        }
        content.addView(goHomeBtn)

        // Center content in root
        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
        }
        root.addView(content, params)

        setContentView(root)
    }

    private fun spacer(heightDp: Int): android.view.View {
        return android.view.View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (heightDp * resources.displayMetrics.density).toInt()
            )
        }
    }

    /**
     * Back button → go to home screen (our launcher), NOT back to blocked app
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        goHome()
    }

    /**
     * If user switches away and comes back (via recents), 
     * and the blocked app is still blocked, keep showing this.
     */
    override fun onResume() {
        super.onResume()
        // Re-check if still blocked (rule might have been deactivated)
        val pkg = blockedPackage
        if (pkg != null) {
            val blocked = AppBlockerService.getBlockedPackages(this)
            if (!blocked.contains(pkg)) {
                // No longer blocked — dismiss this overlay
                finish()
            }
        }
    }

    private fun goHome() {
        // Launch our launcher's main activity
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
        finish()
    }
}
