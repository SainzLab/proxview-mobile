package com.example.proxview

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

class MonitoringAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ProxViewAlarmRcvr"
        const val ACTION_ALARM_POLL = "com.example.proxview.ACTION_ALARM_POLL"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val appCtx = context.applicationContext
        if (!MonitoringForegroundService.isMonitoringEnabled(appCtx)) {
            MonitoringForegroundService.cancelWatchdogAlarm(appCtx)
            return
        }

        // Jadwalkan ulang alarm berikutnya agar tetap hidup meski di Doze Mode
        MonitoringForegroundService.scheduleWatchdogAlarm(appCtx)

        val pendingResult = goAsync()
        val pm = appCtx.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wl = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ProxView:AlarmPollWakeLock"
        ).apply { setReferenceCounted(false) }

        Thread {
            try {
                wl.acquire(20_000L)

                // Pastikan Foreground Service tetap menyala bila sempat dihentikan sistem/OEM
                if (!MonitoringForegroundService.isServiceRunning) {
                    val svcIntent = Intent(appCtx, MonitoringForegroundService::class.java).apply {
                        action = ACTION_ALARM_POLL
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            appCtx.startForegroundService(svcIntent)
                        } else {
                            appCtx.startService(svcIntent)
                        }
                    } catch (t: Throwable) {
                        Log.w(TAG, "Cannot restart FGS from background alarm (${t.message}), running direct poll")
                    }
                }

                // Jalankan pengecekan alert langsung di thread background dengan aman
                if (!MainActivity.isAppInForeground) {
                    MonitoringForegroundService.pollOnce(appCtx)
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Error in MonitoringAlarmReceiver: ${t.message}", t)
            } finally {
                try {
                    if (wl.isHeld) wl.release()
                } catch (_: Throwable) {
                }
                try {
                    pendingResult.finish()
                } catch (_: Throwable) {
                }
            }
        }.start()
    }
}
