package com.luminance.luminance

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log
import android.view.Gravity
import android.view.WindowManager
import android.widget.*
import org.json.JSONObject
import android.view.animation.ScaleAnimation
import android.graphics.*
import android.view.View

class LuminanceBlockerService : AccessibilityService() {

    private var currentPackage: String? = null
    private var sessionStartTime: Long = 0
    private var todayBaseUsageSec: Long = 0
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var checkRunnable: Runnable? = null
    private var overlayView: android.view.View? = null

    private val formalQuotes = listOf(
        "\"Focus is the cornerstone of professional excellence.\"",
        "\"Digital discipline leads to cognitive clarity.\"",
        "\"Your time is a finite resource; use it with intention.\"",
        "\"Success is found in the center of focused effort.\"",
        "\"A disciplined mind is a free mind.\"",
        "\"Prioritize your objectives over digital distractions.\""
    )

    // Custom Lotus Drawing View
    class LotusView(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#00F2FF")
            style = Paint.Style.STROKE
            strokeWidth = 8f
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val centerX = width / 2f
            val centerY = height / 2f
            val radius = 100f
            
            // Draw 8 petals
            for (i in 0 until 8) {
                canvas.save()
                canvas.rotate(i * 45f, centerX, centerY)
                canvas.drawOval(centerX - 40f, centerY - 150f, centerX + 40f, centerY - 50f, paint)
                canvas.restore()
            }
            canvas.drawCircle(centerX, centerY, 30f, paint)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || 
            event?.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            
            val packageName = event.packageName?.toString() ?: return
            
            if (packageName == "com.miui.securitycenter" || 
                packageName == "com.android.settings" || 
                packageName == "com.luminance.luminance" ||
                packageName == "com.android.systemui") {
                return
            }

            if (isAppRestricted(packageName)) {
                if (currentPackage != packageName) {
                    currentPackage = packageName
                    sessionStartTime = System.currentTimeMillis()
                    todayBaseUsageSec = getTodayUsageInSeconds(packageName)
                    startTracking(packageName)
                }
            } else {
                if (packageName.contains("launcher") || packageName.contains("home") || packageName == "android") {
                    hideZenOverlay()
                    currentPackage = null
                    checkRunnable?.let { handler.removeCallbacks(it) }
                }
            }
        }
    }

    private fun startTracking(packageName: String) {
        checkRunnable?.let { handler.removeCallbacks(it) }
        val runnable = object : Runnable {
            override fun run() {
                if (currentPackage == packageName) {
                    val sessionSec = (System.currentTimeMillis() - sessionStartTime) / 1000
                    val totalTodaySec = todayBaseUsageSec + sessionSec
                    if (isLimitExceeded(packageName, totalTodaySec)) {
                        showZenOverlay()
                    } else {
                        handler.postDelayed(this, 1000)
                    }
                }
            }
        }
        checkRunnable = runnable; handler.post(runnable)
    }

    private fun isAppRestricted(packageName: String): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.getBoolean("flutter.childMode", false)) {
            val keywords = listOf("instagram", "facebook", "tiktok", "snapchat", "twitter", "youtube", "shorts", "reels", "game", "pubg", "clash", "chess", "mafia", "innersloth", "tencent", "supercell", "king", "candy", "saga", "roblox", "mojang", "minecraft", "freefire")
            if (keywords.any { packageName.contains(it) }) return true
        }
        return (prefs.getString("flutter.app_block_settings", "{}") ?: "{}").contains(packageName)
    }

    private fun isLimitExceeded(packageName: String, totalSec: Long): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.getBoolean("flutter.childMode", false)) {
            val keywords = listOf("instagram", "facebook", "tiktok", "snapchat", "twitter", "youtube", "shorts", "reels", "game", "pubg", "clash", "chess", "mafia", "innersloth", "tencent", "supercell", "king", "candy", "saga", "roblox", "mojang", "minecraft", "freefire")
            if (keywords.any { packageName.contains(it) }) return totalSec >= 10 
        }
        try {
            val settings = JSONObject(prefs.getString("flutter.app_block_settings", "{}") ?: "{}")
            val cfg = settings.optJSONObject(packageName) ?: return false
            if (!cfg.optBoolean("enabled", false)) return false
            return totalSec >= (cfg.optInt("h", 0) * 3600 + cfg.optInt("m", 0) * 60 + cfg.optInt("s", 0))
        } catch (e: Exception) { return false }
    }

    private fun getTodayUsageInSeconds(packageName: String): Long {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0); calendar.set(java.util.Calendar.MINUTE, 0); calendar.set(java.util.Calendar.SECOND, 0)
            return (usm.queryAndAggregateUsageStats(calendar.timeInMillis, System.currentTimeMillis())[packageName]?.totalTimeInForeground ?: 0L) / 1000
        } catch (e: Exception) { return 0 }
    }

    private fun showZenOverlay() {
        if (overlayView != null) return
        handler.post {
            try {
                val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_FULLSCREEN,
                    android.graphics.PixelFormat.TRANSLUCENT
                )

                val root = FrameLayout(this)
                root.setBackgroundColor(Color.parseColor("#FF0A192F")) // 100% Opaque
                root.isClickable = true

                val content = LinearLayout(this)
                content.orientation = LinearLayout.VERTICAL; content.gravity = Gravity.CENTER
                
                // 1. Custom Lotus View
                val lotus = LotusView(this)
                content.addView(lotus, LinearLayout.LayoutParams(500, 500))
                
                // Animation
                val breath = ScaleAnimation(0.9f, 1.1f, 0.9f, 1.1f, 1, 0.5f, 1, 0.5f)
                breath.duration = 4000; breath.repeatCount = -1; breath.repeatMode = 2
                lotus.startAnimation(breath)

                // 2. Formal Text
                val title = TextView(this)
                title.text = "LUMINANCE FOCUS"; title.setTextColor(Color.parseColor("#00F2FF"))
                title.textSize = 24f; title.setPadding(0, 40, 0, 10); content.addView(title)

                val sub = TextView(this)
                sub.text = "Breathe with the lotus. Focus on your objectives."; sub.setTextColor(Color.WHITE)
                sub.textSize = 14f; sub.alpha = 0.6f; content.addView(sub)

                // 3. Formal Quote
                val quote = TextView(this)
                quote.text = formalQuotes.random(); quote.setTextColor(Color.WHITE)
                quote.gravity = Gravity.CENTER; quote.textSize = 18f; quote.setPadding(60, 60, 60, 60)
                quote.setTypeface(null, Typeface.ITALIC)
                content.addView(quote)

                val btn = Button(this)
                btn.text = "RETURN TO DASHBOARD"
                btn.setBackgroundColor(Color.parseColor("#00F2FF"))
                btn.setTextColor(Color.BLACK)
                btn.setOnClickListener { hideZenOverlay(); performGlobalAction(GLOBAL_ACTION_HOME) }
                content.addView(btn, LinearLayout.LayoutParams(600, 140))

                root.addView(content)
                overlayView = root; wm.addView(root, params)
            } catch (e: Exception) { }
        }
    }

    private fun hideZenOverlay() {
        if (overlayView == null) return
        handler.post { try { (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(overlayView); overlayView = null } catch (e: Exception) { } }
    }

    override fun onInterrupt() {}
}
