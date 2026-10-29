package com.example.proxview

import android.annotation.SuppressLint
import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.example.proxview/background_monitor"

        @Volatile
        var isAppInForeground: Boolean = false

        private var askedBatteryThisProcess: Boolean = false
        private var askedFsiThisProcess: Boolean = false
    }

    private var methodChannel: MethodChannel? = null
    private var pendingEmergencyAlertId: Int? = null
    private var pendingOpenAlertsTab: Boolean = false
    private var checkFsiOnNextResume: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenDisplay()
        CallRingtoneManager.ensureChannels(this)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        isAppInForeground = true
        if (checkFsiOnNextResume) {
            checkFsiOnNextResume = false
            promptFullScreenIntentIfNeeded()
        }
    }

    override fun onPause() {
        isAppInForeground = false
        super.onPause()
    }

    override fun onStop() {
        isAppInForeground = false
        super.onStop()
    }

    override fun onDestroy() {
        isAppInForeground = false
        methodChannel = null
        super.onDestroy()
    }

    private fun handleNotificationIntent(incoming: Intent?) {
        if (incoming == null) return
        val emergencyId = incoming.getIntExtra("emergency_alert_id", -1)
        val answered = incoming.getBooleanExtra("answer_emergency_call", false)
        val openAlertsTab = incoming.getBooleanExtra("open_alerts_tab", false)

        if (emergencyId > 0) {
            enableLockScreenDisplay()
            if (answered) {
                // Hentikan bunyi dering & banner statusbar saat teknisi menekan "BUKA & TANGANI",
                // namun JANGAN tandai dismissed agar layar EmergencyCallView tetap terbuka di aplikasi.
                CallRingtoneManager.stopCallRingtone(this, emergencyId)
            }
            pendingEmergencyAlertId = emergencyId
            methodChannel?.invokeMethod("onEmergencyAlertOpened", emergencyId)
            incoming.removeExtra("emergency_alert_id")
            incoming.removeExtra("answer_emergency_call")
        } else if (openAlertsTab) {
            pendingOpenAlertsTab = true
            methodChannel?.invokeMethod("onOpenAlertsTab", null)
            incoming.removeExtra("open_alerts_tab")
        }
    }

    @SuppressLint("BatteryLife")
    private fun requestBackgroundReliabilityPermissions() {
        // 1. Minta pengecualian penghemat baterai (Doze / OEM Freezer) agar koneksi jaringan background tidak dibekukan saat di-close
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !askedBatteryThisProcess) {
            try {
                val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                    askedBatteryThisProcess = true
                    checkFsiOnNextResume = true
                    val batteryIntent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(batteryIntent)
                    return
                }
            } catch (_: Throwable) {
            }
        }

        // 2. Jika Battery Optimization sudah diizinkan, pastikan izin Full-Screen Intent (Android 14+) aktif untuk layar panggilan darurat
        promptFullScreenIntentIfNeeded()
    }

    private fun promptFullScreenIntentIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && !askedFsiThisProcess) {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (!nm.canUseFullScreenIntent()) {
                    askedFsiThisProcess = true
                    val fsiIntent = Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(fsiIntent)
                }
            } catch (_: Throwable) {
            }
        }
    }

    private fun openOemAutoStartSettings() {
        val oemIntents = listOf(
            // ColorOS / Realme UI
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.oplus.battery", "com.oplus.battery.AppBatteryManagerActivity")),
            Intent().setComponent(android.content.ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity")),
            // Xiaomi / MIUI / HyperOS
            Intent().setComponent(android.content.ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            // Huawei
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(android.content.ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            // Vivo
            Intent().setComponent(android.content.ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(android.content.ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            // Samsung
            Intent().setComponent(android.content.ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"))
        )

        for (intent in oemIntents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (packageManager.resolveActivity(intent, 0) != null) {
                    startActivity(intent)
                    return
                }
            } catch (_: Throwable) {
            }
        }

        // Fallback 1: Pengaturan Detail Aplikasi (Info Aplikasi -> Penggunaan Baterai / Izin)
        try {
            val detailsIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(detailsIntent)
        } catch (_: Throwable) {
            // Fallback 2: Pengaturan Penghemat Baterai Sistem
            try {
                val batteryIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(batteryIntent)
            } catch (_: Throwable) {
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = ch

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "configureAndStartService" -> {
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    val apiToken = call.argument<String>("apiToken") ?: ""
                    val enabled = call.argument<Boolean>("enabled") ?: false

                    MonitoringForegroundService.saveServiceConfig(
                        context = this,
                        baseUrl = baseUrl,
                        apiToken = apiToken,
                        enabled = enabled
                    )

                    val serviceIntent = Intent(this, MonitoringForegroundService::class.java)
                    try {
                        if (enabled && baseUrl.isNotBlank() && apiToken.isNotBlank()) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                        } else {
                            stopService(serviceIntent)
                        }
                    } catch (_: Throwable) {
                    }
                    result.success(true)
                }

                "requestBackgroundPermissions" -> {
                    requestBackgroundReliabilityPermissions()
                    result.success(true)
                }

                "stopService" -> {
                    MonitoringForegroundService.clearServiceConfig(this)
                    try {
                        stopService(Intent(this, MonitoringForegroundService::class.java))
                    } catch (_: Throwable) {
                    }
                    CallRingtoneManager.stopCallRingtone(this, null)
                    result.success(true)
                }

                "getInitialNotificationState" -> {
                    val known = MonitoringForegroundService.getKnownAlertsMap(this)
                    val dismissed = MonitoringForegroundService.getDismissedSet(this).toList()
                    val launchEmergencyId = pendingEmergencyAlertId
                    val launchAlertsTab = pendingOpenAlertsTab
                    pendingEmergencyAlertId = null
                    pendingOpenAlertsTab = false

                    result.success(
                        mapOf(
                            "knownAlerts" to known,
                            "dismissedCallIds" to dismissed,
                            "emergencyAlertId" to launchEmergencyId,
                            "openAlertsTab" to launchAlertsTab
                        )
                    )
                }

                "syncAlertState" -> {
                    @Suppress("UNCHECKED_CAST")
                    val knownMap = call.argument<Map<String, String>>("knownAlerts") ?: emptyMap()
                    val dismissedList = call.argument<List<Int>>("dismissedCallIds") ?: emptyList()
                    val overwriteKnown = call.argument<Boolean>("overwriteKnown") ?: true

                    MonitoringForegroundService.saveSyncState(
                        context = this,
                        knownAlerts = knownMap,
                        dismissedIds = dismissedList,
                        overwriteKnownAlerts = overwriteKnown
                    )
                    val mergedDismissed = MonitoringForegroundService.getDismissedSet(this).toList()
                    result.success(mergedDismissed)
                }

                "startCallRingtone" -> {
                    val alertId = call.argument<Int>("alertId") ?: 1
                    val severity = call.argument<String>("severity") ?: "CRITICAL"
                    val targetType = call.argument<String>("targetType") ?: "SYSTEM"
                    val targetName = call.argument<String>("targetName") ?: "Target"
                    val message = call.argument<String>("message") ?: "Gangguan Terdeteksi"

                    enableLockScreenDisplay()
                    CallRingtoneManager.triggerIncomingCall(
                        context = this,
                        alertId = alertId,
                        severity = severity,
                        targetType = targetType,
                        targetName = targetName,
                        message = message,
                        launchActivityIfBackground = false
                    )
                    result.success(true)
                }

                "stopCallRingtone" -> {
                    val alertId = call.argument<Int>("alertId")
                    if (alertId != null) {
                        MonitoringForegroundService.markCallDismissed(this, alertId)
                    }
                    CallRingtoneManager.stopCallRingtone(this, alertId)
                    result.success(true)
                }

                "getBackgroundServiceDiagnostics" -> {
                    val diag = MonitoringForegroundService.getDiagnostics(this).toMutableMap()
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isBattIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val canFsi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        nm.canUseFullScreenIntent()
                    } else {
                        true
                    }
                    diag["isBatteryOptimizationIgnored"] = isBattIgnored
                    diag["canUseFullScreenIntent"] = canFsi
                    result.success(diag)
                }

                "openAutoStartSettings" -> {
                    openOemAutoStartSettings()
                    result.success(true)
                }

                "testEmergencyCall" -> {
                    enableLockScreenDisplay()
                    CallRingtoneManager.triggerIncomingCall(
                        context = this,
                        alertId = 99999,
                        severity = "DOWN",
                        targetType = "PROXMOX-VM",
                        targetName = "Uji Coba Alarm NOC",
                        message = "Uji coba panggilan darurat dan dering sistem ProxView. Audio, getaran, dan layar darurat bekerja normal.",
                        launchActivityIfBackground = true
                    )
                    result.success(true)
                }

                "testStandardAlert" -> {
                    CallRingtoneManager.showStandardAlertNotification(
                        context = this,
                        alertId = 99998,
                        severity = "WARNING",
                        targetName = "Uji Coba Notifikasi",
                        message = "Notifikasi gangguan dan spanduk heads-up berfungsi normal di perangkat ini."
                    )
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun enableLockScreenDisplay() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                km.requestDismissKeyguard(this, null)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
        } catch (_: Throwable) {
        }
    }
}
