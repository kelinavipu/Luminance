package com.luminance.luminance

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.luminance/usage"
    
    companion object {
        var instance: MainActivity? = null
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
    }

    // Packages always excluded from screen time (same as Digital Wellbeing)
    private val EXCLUDED_PACKAGES = setOf(
        "com.android.systemui",
        "com.android.launcher", "com.android.launcher2", "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.samsung.android.app.launcher",
        "com.miui.home", "com.oppo.launcher", "com.vivo.launcher",
        "com.oneplus.launcher", "com.huawei.android.launcher",
        "com.android.inputmethod.latin",
        "com.google.android.inputmethod.latin",
        "com.samsung.android.honeyboard",
        "com.swiftkey.swiftkeyapp", "com.touchtype.swiftkey",
        "com.google.android.gms", "com.google.android.gsf",
        "com.android.phone", "com.android.server.telecom", "com.android.dialer",
        "android", "com.android.settings",
        "com.android.packageinstaller", "com.google.android.packageinstaller"
    )

    private var pendingBlockedApp: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Capture blocked app from initial intent if present
        if (intent?.hasExtra("blocked_app") == true) {
            pendingBlockedApp = intent.getStringExtra("blocked_app")
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.luminance/usage")
        methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUsagePermission"      -> result.success(hasUsageStatsPermission())
                    "requestUsagePermission"  -> { requestUsagePermission(); result.success(true) }
                    "getForegroundScreenTime" -> result.success(getForegroundScreenTime())
                    "getUnlockCount"          -> result.success(getUnlockCount())
                    "getTopAppUsage"          -> result.success(getTopAppUsage())
                    "getNightUsageStats"      -> result.success(getNightUsageStats())
                    "getWeeklyUsageData"      -> result.success(getWeeklyUsageData())
                    "getForegroundApp"        -> result.success(getForegroundApp())
                    "getTopAppUsagePackages"  -> result.success(getTopAppUsagePackages())
                    "getPendingBlock"         -> { 
                        val app = pendingBlockedApp
                        pendingBlockedApp = null
                        result.success(app)
                    }
                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Static helper to allow service to push data
    fun notifyBlock(packageName: String) {
        runOnUiThread {
            methodChannel?.invokeMethod("onBlockTriggered", packageName)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val blockedApp = intent.getStringExtra("blocked_app")
        if (blockedApp != null) {
            pendingBlockedApp = blockedApp
            notifyBlock(blockedApp)
        }
    }

    private fun getTopAppUsagePackages(): Map<String, Double> {
        return buildTodayUsageMsPackages()
            .mapValues { it.value / (1000.0 * 60.0 * 60.0) }
            .toList()
            .sortedByDescending { it.second }
            .toMap()
    }

    // ── Permission check ──────────────────────────────────────────────────────

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsagePermission() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun getForegroundApp(): String? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - 1000 * 60, now) ?: return null
        val event = UsageEvents.Event()
        var lastPkg: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastPkg = event.packageName
            }
        }
        return lastPkg
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /** Total foreground screen time today in hours. Matches Digital Wellbeing. */
    private fun getForegroundScreenTime(): Double {
        val ms = buildTodayUsageMs().values.sumOf { it }
        return ms / (1000.0 * 60.0 * 60.0)
    }

    /** Top apps today: { appName -> hours }. Used by DigiGuide. */
    private fun getTopAppUsage(): Map<String, Double> {
        return buildTodayUsageMs()
            .mapValues { it.value / (1000.0 * 60.0 * 60.0) }
            .toList()
            .sortedByDescending { it.second }
            .toMap()
    }

    // ── Core: event-based tracking (matches Digital Wellbeing) ───────────────

    private fun buildTodayUsageMs(): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(startOfDay, now) ?: return emptyMap()

        val foregroundStart = mutableMapOf<String, Long>()
        val rawUsage = mutableMapOf<String, Long>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName
            if (EXCLUDED_PACKAGES.contains(pkg)) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> foregroundStart[pkg] = event.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = foregroundStart.remove(pkg) ?: continue
                    val elapsed = event.timeStamp - start
                    if (elapsed > 0L) rawUsage[pkg] = (rawUsage[pkg] ?: 0L) + elapsed
                }
            }
        }
        for ((pkg, start) in foregroundStart) {
            val elapsed = now - start
            if (elapsed > 0L) rawUsage[pkg] = (rawUsage[pkg] ?: 0L) + elapsed
        }

        val result = mutableMapOf<String, Long>()
        for ((pkg, ms) in rawUsage) {
            val label = try {
                val info = context.packageManager.getApplicationInfo(pkg, 0)
                context.packageManager.getApplicationLabel(info).toString()
            } catch (_: Exception) { pkg }
            result[label] = (result[label] ?: 0L) + ms
        }
        return result
    }

    private fun buildTodayUsageMsPackages(): Map<String, Long> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(startOfDay, now) ?: return emptyMap()

        val foregroundStart = mutableMapOf<String, Long>()
        val rawUsage = mutableMapOf<String, Long>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> foregroundStart[pkg] = event.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = foregroundStart.remove(pkg) ?: continue
                    val elapsed = event.timeStamp - start
                    if (elapsed > 0L) rawUsage[pkg] = (rawUsage[pkg] ?: 0L) + elapsed
                }
            }
        }
        for ((pkg, start) in foregroundStart) {
            val elapsed = now - start
            if (elapsed > 0L) rawUsage[pkg] = (rawUsage[pkg] ?: 0L) + elapsed
        }
        return rawUsage
    }

    /**
     * Pure system packages: FLAG_SYSTEM set but NOT FLAG_UPDATED_SYSTEM_APP.
     * Updated system apps like Chrome, Gmail, YouTube are NOT in this set,
     * so they are counted — same behaviour as Digital Wellbeing.
     */
    private fun getSystemOnlyPackages(): Set<String> {
        return try {
            context.packageManager.getInstalledApplications(0)
                .filter { info ->
                    val isSystem  = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                    val isUpdated = (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                    isSystem && !isUpdated
                }
                .map { it.packageName }
                .toSet()
        } catch (_: Exception) { emptySet() }
    }

    // ── Additional Metrics (Unlocks, Night Usage, Weekly) ────────────────────

    private fun getUnlockCount(): Int {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val now = System.currentTimeMillis()

        val events = usm.queryEvents(startOfDay, now) ?: return 0
        var unlockCount = 0
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            // KEYGUARD_HIDDEN usually corresponds to a screen unlock
            if (event.eventType == UsageEvents.Event.KEYGUARD_HIDDEN) {
                unlockCount++
            }
        }
        return unlockCount
    }

    private fun getNightUsageStats(): Map<String, Any> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        // 10 PM yesterday to 6 AM today
        val startOfNight = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -1)
            set(Calendar.HOUR_OF_DAY, 22); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val endOfNight = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 6); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val events = usm.queryEvents(startOfNight, endOfNight)
        val nightApps = mutableSetOf<String>()
        val systemPkgs = getSystemOnlyPackages()
        var activeUsageEvents = 0
        
        if (events != null) {
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND && 
                    !EXCLUDED_PACKAGES.contains(pkg) && !systemPkgs.contains(pkg)) {
                    nightApps.add(pkg)
                    activeUsageEvents++
                }
            }
        }

        return mapOf(
            "appsOpened" to nightApps.size,
            "isPassive" to (activeUsageEvents < 5) // Simple heuristic
        )
    }

    private fun getWeeklyUsageData(): List<Double> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val weeklyData = mutableListOf<Double>()
        
        // Go back 7 days
        for (i in 6 downTo 0) {
            val startOfDay = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -i)
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            
            val endOfDay = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -i)
                set(Calendar.HOUR_OF_DAY, 23); set(Calendar.MINUTE, 59); set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999)
            }.timeInMillis

            val events = usm.queryEvents(startOfDay, endOfDay)
            val foregroundStart = mutableMapOf<String, Long>()
            var totalMsForDay = 0L
            val systemPkgs = getSystemOnlyPackages()

            if (events != null) {
                val event = UsageEvents.Event()
                while (events.hasNextEvent()) {
                    events.getNextEvent(event)
                    val pkg = event.packageName
                    if (EXCLUDED_PACKAGES.contains(pkg) || systemPkgs.contains(pkg)) continue

                    if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                        foregroundStart[pkg] = event.timeStamp
                    } else if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                        val start = foregroundStart.remove(pkg)
                        if (start != null) {
                            totalMsForDay += (event.timeStamp - start)
                        }
                    }
                }
                
                // Add any still open at end of day
                for ((_, start) in foregroundStart) {
                    if (endOfDay > start) {
                        totalMsForDay += (endOfDay - start)
                    }
                }
            }
            weeklyData.add(totalMsForDay / (1000.0 * 60.0 * 60.0))
        }
        return weeklyData
    }
}
