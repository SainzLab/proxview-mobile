package com.example.proxview

import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

object CallRingtoneManager {
    private const val TAG = "ProxViewCallMgr"

    const val CALL_CHANNEL_ID = "proxview_emergency_call_v4"
    const val ALERT_CHANNEL_ID = "proxview_alerts_v4"
    const val FG_CHANNEL_ID = "proxview_bg_service_v2"

    private var mediaPlayer: MediaPlayer? = null
    private var fallbackRingtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    @Volatile
    private var currentRingingAlertId: Int? = null

    @Synchronized
    fun isCurrentlyRinging(): Boolean {
        val mpPlaying = try {
            mediaPlayer?.isPlaying == true
        } catch (_: Throwable) {
            false
        }
        val rtPlaying = try {
            fallbackRingtone?.isPlaying == true
        } catch (_: Throwable) {
            false
        }
        return currentRingingAlertId != null && (mpPlaying || rtPlaying)
    }

    @Synchronized
    fun isRingingFor(alertId: Int): Boolean {
        return currentRingingAlertId == alertId && isCurrentlyRinging()
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Bersihkan channel versi lama agar pengaturan baru (suara & heads-up) diterapkan bersih
        try {
            nm.deleteNotificationChannel("proxview_emergency_call_v1")
            nm.deleteNotificationChannel("proxview_emergency_call_v2")
            nm.deleteNotificationChannel("proxview_emergency_call_v3")
            nm.deleteNotificationChannel("proxview_alerts_v1")
            nm.deleteNotificationChannel("proxview_alerts_v2")
            nm.deleteNotificationChannel("proxview_alerts_v3")
            nm.deleteNotificationChannel("proxview_bg_service_v1")
        } catch (_: Throwable) {
        }

        // 1. Channel Panggilan Darurat (Incoming Call seperti Telepon/WhatsApp)
        val callChannel = NotificationChannel(
            CALL_CHANNEL_ID,
            "Panggilan Darurat Insiden",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Panggilan darurat layar penuh saat terjadi gangguan kritis/down"
            enableVibration(true)
            enableLights(true)
            lightColor = Color.RED
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
            enableLights(true)
            vibrationPattern = longArrayOf(0, 400, 200, 400)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            val notifUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            if (notifUri != null) {
                val audioAttr = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                setSound(notifUri, audioAttr)
            }
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

    fun buildActivityPendingIntent(
        context: Context,
        requestCode: Int,
        intent: Intent
    ): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try {
                val options = ActivityOptions.makeBasic()
                    .setPendingIntentCreatorBackgroundActivityStartMode(
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    )
                return PendingIntent.getActivity(
                    context,
                    requestCode,
                    intent,
                    flags,
                    options.toBundle()
                )
            } catch (_: Throwable) {
            }
        }
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    @Synchronized
    fun startCallRingtoneAndVibration(context: Context, alertId: Int) {
        if (isRingingFor(alertId)) {
            return
        }
        stopRingtoneAndVibrationOnly()
        currentRingingAlertId = alertId

        // Bangunkan layar perangkat jika sedang mati/terkunci
        wakeUpScreen(context, 20_000L)

        val appCtx = context.applicationContext
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        // Putar nada dering telepon secara looping (dengan fallback Ringtone sistem jika URI OEM terkunci)
        var startedMedia = false
        if (uri != null) {
            try {
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(appCtx, uri)
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
                startedMedia = true
            } catch (t: Throwable) {
                Log.w(TAG, "MediaPlayer ringtone failed (${t.message}), falling back to system Ringtone")
                mediaPlayer = null
            }

            if (!startedMedia) {
                try {
                    val rt = RingtoneManager.getRingtone(appCtx, uri)
                    if (rt != null) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            rt.isLooping = true
                        }
                        rt.audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        rt.play()
                        fallbackRingtone = rt
                    }
                } catch (t: Throwable) {
                    Log.w(TAG, "Fallback Ringtone failed: ${t.message}")
                }
            }
        }

        // Getarkan perangkat secara berulang seperti panggilan telepon masuk
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = appCtx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                appCtx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
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
        } catch (t: Throwable) {
            Log.w(TAG, "Vibration failed: ${t.message}")
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
        } catch (_: Throwable) {
        } finally {
            mediaPlayer = null
        }

        try {
            fallbackRingtone?.let {
                if (it.isPlaying) it.stop()
            }
        } catch (_: Throwable) {
        } finally {
            fallbackRingtone = null
        }

        try {
            vibrator?.cancel()
        } catch (_: Throwable) {
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
            } catch (_: Throwable) {
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
        val fullScreenPendingIntent = buildActivityPendingIntent(
            context,
            alertId,
            openIntent
        )

        // Tombol "BUKA & TANGANI" langsung menuju MainActivity (bukan BroadcastReceiver)
        // agar tidak diblokir aturan Notification Trampoline Android 12-15!
        val answerIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("emergency_alert_id", alertId)
            putExtra("answer_emergency_call", true)
        }
        val answerPendingIntent = buildActivityPendingIntent(
            context,
            alertId + 10000,
            answerIntent
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

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val canUseFsi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            nm.canUseFullScreenIntent()
        } else {
            true
        }

        var postedCallStyle = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && canUseFsi) {
            try {
                val caller = Person.Builder()
                    .setName("[$severity] $targetName")
                    .setImportant(true)
                    .build()

                val callStyle = Notification.CallStyle.forIncomingCall(
                    caller,
                    dismissPendingIntent,
                    answerPendingIntent
                )

                val callNotif = Notification.Builder(context, CALL_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.launcher_icon)
                    .setContentTitle("PANGGILAN DARURAT: [$severity] $targetName")
                    .setContentText("$targetType • $message")
                    .setStyle(callStyle)
                    .setCategory(Notification.CATEGORY_CALL)
                    .setVisibility(Notification.VISIBILITY_PUBLIC)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setContentIntent(fullScreenPendingIntent)
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .build()

                callNotif.flags = callNotif.flags or Notification.FLAG_INSISTENT
                nm.notify(alertId, callNotif)
                postedCallStyle = true
            } catch (t: Throwable) {
                Log.w(TAG, "CallStyle notification fallback: ${t.message}")
            }
        }

        if (!postedCallStyle) {
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
                nm.notify(alertId, notification)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to post call notification: ${t.message}", t)
            }
        }

        // Jika perangkat mengizinkan overlay/background activity start, langsung angkat layar panggilan
        if (launchActivityIfBackground && !MainActivity.isAppInForeground) {
            try {
                context.startActivity(openIntent)
            } catch (_: Throwable) {
                // Pada Android 10-15 tanpa SYSTEM_ALERT_WINDOW, peluncuran ditangani oleh setFullScreenIntent di atas
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
        wakeUpScreen(context, 5_000L)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_alerts_tab", true)
            putExtra("alert_id", alertId)
        }
        val contentPendingIntent = buildActivityPendingIntent(
            context,
            alertId + 30000,
            openIntent
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
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to post alert notification: ${t.message}", t)
        }
    }

    private fun wakeUpScreen(context: Context, timeoutMs: Long) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE,
                "ProxView:EmergencyCallWakeLock"
            ).apply { setReferenceCounted(false) }
            wl.acquire(timeoutMs)
        } catch (_: Throwable) {
        }
    }
}
