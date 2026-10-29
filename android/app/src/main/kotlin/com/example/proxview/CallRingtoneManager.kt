package com.example.proxview

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object CallRingtoneManager {
    const val CALL_CHANNEL_ID = "proxview_emergency_call_v2"
    const val ALERT_CHANNEL_ID = "proxview_alerts_v2"
    const val FG_CHANNEL_ID = "proxview_bg_service_v1"

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var currentRingingAlertId: Int? = null

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. Channel Panggilan Darurat (Incoming Call seperti Telepon/WhatsApp)
        val callChannel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Panggilan Darurat Insiden",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Panggilan darurat layar penuh saat terjadi gangguan kritis/down"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            val audioAttr = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(ringtoneUri, audioAttr)
        }

        // 2. Channel Notifikasi Gangguan Biasa (Pesan)
        val alertChannel = NotificationChannel(
            ALERT_CHANNEL_ID,
            "Notifikasi Gangguan & Insiden",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Pemberitahuan real-time saat terdeteksi gangguan pada Proxmox atau Jaringan"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 400, 200, 400)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        // 3. Channel Status Background Monitoring Service
        val fgChannel = NotificationChannel(
            FG_CHANNEL_ID,
            "Layanan Pemantauan Latar Belakang",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Menjaga pemantauan insiden & panggilan darurat tetap aktif di latar belakang"
            setShowBadge(false)
        }

        nm.createNotificationChannel(callChannel)
        nm.createNotificationChannel(alertChannel)
        nm.createNotificationChannel(fgChannel)
    }

    @Synchronized
    fun startCallRingtoneAndVibration(context: Context, alertId: Int) {
        if (currentRingingAlertId == alertId && mediaPlayer?.isPlaying == true) {
            return
        }
        stopRingtoneAndVibrationOnly()
        currentRingingAlertId = alertId

        // Bangunkan layar perangkat jika sedang mati/terkunci
        wakeUpScreen(context)

        // Putar nada dering telepon secara looping
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (uri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(context.applicationContext, uri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    isLooping = true
                    prepare()
                    start()
                }
            }
        } catch (_: Exception) {
        }

        // Getarkan perangkat secara berulang seperti panggilan telepon masuk
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator = vib
            val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val audioAttr = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .build()
                @Suppress("DEPRECATION")
                vib.vibrate(VibrationEffect.createWaveform(pattern, 0), audioAttr)
            } else {
                @Suppress("DEPRECATION")
                vib.vibrate(pattern, 0)
            }
        } catch (_: Exception) {
        }
    }

    @Synchronized
    fun stopRingtoneAndVibrationOnly() {
        currentRingingAlertId = null
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {
        } finally {
            mediaPlayer = null
        }

        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        } finally {
            vibrator = null
        }
    }

    @Synchronized
    fun stopCallRingtone(context: Context, alertId: Int? = null) {
        val targetId = alertId ?: currentRingingAlertId
        stopRingtoneAndVibrationOnly()
        if (targetId != null) {
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(targetId)
            } catch (_: Exception) {
            }
        }
    }

    fun triggerIncomingCall(
        context: Context,
        alertId: Int,
        severity: String,
        targetType: String,
        targetName: String,
        message: String,
        launchActivityIfBackground: Boolean = true
    ) {
        ensureChannels(context)
        startCallRingtoneAndVibration(context, alertId)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("emergency_alert_id", alertId)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            alertId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val answerIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_ANSWER_CALL
            putExtra(CallActionReceiver.EXTRA_ALERT_ID, alertId)
        }
        val answerPendingIntent = PendingIntent.getBroadcast(
            context,
            alertId + 10000,
            answerIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_DISMISS_CALL
            putExtra(CallActionReceiver.EXTRA_ALERT_ID, alertId)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            alertId + 20000,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CALL_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val answerAction = Notification.Action.Builder(
            android.R.drawable.sym_action_call,
            "BUKA & TANGANI",
            answerPendingIntent
        ).build()

        val dismissAction = Notification.Action.Builder(
            android.R.drawable.ic_menu_close_clear_cancel,
            "TUTUP ALARM",
            dismissPendingIntent
        ).build()

        builder.setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("PANGGILAN DARURAT: [$severity] $targetName")
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText("$targetType • $message"))
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .addAction(answerAction)
            .addAction(dismissAction)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_MAX)
        }

        val notification = builder.build()
        notification.flags = notification.flags or Notification.FLAG_INSISTENT

        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(alertId, notification)
        } catch (_: Exception) {
        }

        // Jika aplikasi sedang di background, angkat MainActivity agar layar panggilan muncul seperti WhatsApp
        if (launchActivityIfBackground && !MainActivity.isAppInForeground) {
            try {
                context.startActivity(openIntent)
            } catch (_: Exception) {
            }
        }
    }

    fun showStandardAlertNotification(
        context: Context,
        alertId: Int,
        severity: String,
        targetName: String,
        message: String
    ) {
        ensureChannels(context)
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            alertId + 30000,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ALERT_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder.setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("[$severity] $targetName")
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
        }

        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(alertId, builder.build())
        } catch (_: Exception) {
        }
    }

    private fun wakeUpScreen(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                "ProxView:EmergencyCallWakeLock"
            )
            wl.acquire(15_000L)
        } catch (_: Exception) {
        }
    }
}
