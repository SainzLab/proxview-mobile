package com.example.proxview

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.example.proxview/background_monitor"
        @Volatile
        var isAppInForeground: Boolean = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenDisplay()
        CallRingtoneManager.ensureChannels(this)
    }

    override fun onResume() {
        super.onResume()
        isAppInForeground = true
    }

    override fun onPause() {
        isAppInForeground = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configureAndStartService" -> {
                        val baseUrl = call.argument<String>("baseUrl") ?: ""
                        val apiToken = call.argument<String>("apiToken") ?: ""
                        val enabled = call.argument<Boolean>("enabled") ?: false

                        val prefs = getSharedPreferences(
                            MonitoringForegroundService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        prefs.edit()
                            .putString(MonitoringForegroundService.KEY_BASE_URL, baseUrl)
                            .putString(MonitoringForegroundService.KEY_API_TOKEN, apiToken)
                            .putBoolean(MonitoringForegroundService.KEY_ENABLED, enabled)
                            .apply()

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
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }

                    "stopService" -> {
                        val prefs = getSharedPreferences(
                            MonitoringForegroundService.PREFS_NAME,
                            Context.MODE_PRIVATE
                        )
                        prefs.edit()
                            .putBoolean(MonitoringForegroundService.KEY_ENABLED, false)
                            .apply()
                        try {
                            stopService(Intent(this, MonitoringForegroundService::class.java))
                        } catch (_: Exception) {
                        }
                        CallRingtoneManager.stopCallRingtone(this, null)
                        result.success(true)
                    }

                    "syncAlertState" -> {
                        @Suppress("UNCHECKED_CAST")
                        val knownMap = call.argument<Map<String, String>>("knownAlerts") ?: emptyMap()
                        val dismissedList = call.argument<List<Int>>("dismissedCallIds") ?: emptyList()

                        MonitoringForegroundService.saveSyncState(this, knownMap, dismissedList)
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
        } catch (_: Exception) {
        }
    }
}
