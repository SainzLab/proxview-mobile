package com.example.proxview

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ProxViewBootRcvr"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val appCtx = context.applicationContext
        if (!MonitoringForegroundService.isMonitoringEnabled(appCtx)) {
            return
        }

        MonitoringForegroundService.scheduleWatchdogAlarm(appCtx, delayMs = 5_000L)
        val svcIntent = Intent(appCtx, MonitoringForegroundService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                appCtx.startForegroundService(svcIntent)
            } else {
                appCtx.startService(svcIntent)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Deferred FGS start on $action via watchdog alarm: ${t.message}")
        }
    }
}
