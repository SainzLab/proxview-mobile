package com.example.proxview

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CallActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_DISMISS_CALL = "com.example.proxview.ACTION_DISMISS_CALL"
        const val ACTION_ANSWER_CALL = "com.example.proxview.ACTION_ANSWER_CALL"
        const val EXTRA_ALERT_ID = "extra_alert_id"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        val alertId = intent.getIntExtra(EXTRA_ALERT_ID, -1)

        when (action) {
            ACTION_DISMISS_CALL -> {
                if (alertId != -1) {
                    MonitoringForegroundService.markCallDismissed(context, alertId)
                }
                CallRingtoneManager.stopCallRingtone(context, if (alertId != -1) alertId else null)
            }
            ACTION_ANSWER_CALL -> {
                // Hentikan notifikasi di status bar dan buka layar utama (EmergencyCallView)
                CallRingtoneManager.stopRingtoneAndVibrationOnly()
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("emergency_alert_id", alertId)
                }
                try {
                    context.startActivity(openIntent)
                } catch (_: Exception) {
                }
            }
        }
    }
}
