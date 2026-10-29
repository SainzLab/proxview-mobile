package com.example.proxview

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class MonitoringForegroundService : Service() {
    companion object {
        const val PREFS_NAME = "proxview_bg_prefs"
        const val KEY_BASE_URL = "base_url"
        const val KEY_API_TOKEN_ENC = "api_token_enc"
        private const val LEGACY_KEY_API_TOKEN = "api_token"
        const val KEY_ENABLED = "enabled"
        const val KEY_KNOWN_ALERTS = "known_alerts_json"
        const val KEY_DISMISSED_CALLS = "dismissed_calls_csv"
        private const val FG_NOTIFICATION_ID = 99001
        private const val KEYSTORE_ALIAS = "ProxViewBgTokenKey"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"

        private fun getOrCreateSecretKey(): SecretKey? {
            return try {
                val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
                val existing = keyStore.getEntry(KEYSTORE_ALIAS, null) as? KeyStore.SecretKeyEntry
                if (existing != null) return existing.secretKey

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val keyGenerator = KeyGenerator.getInstance(
                        KeyProperties.KEY_ALGORITHM_AES,
                        ANDROID_KEYSTORE
                    )
                    val spec = KeyGenParameterSpec.Builder(
                        KEYSTORE_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setKeySize(256)
                        .build()
                    keyGenerator.init(spec)
                    keyGenerator.generateKey()
                } else {
                    null
                }
            } catch (_: Exception) {
                null
            }
        }

        private fun encryptToken(plainText: String): String? {
            if (plainText.isBlank()) return null
            return try {
                val secretKey = getOrCreateSecretKey() ?: return null
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.ENCRYPT_MODE, secretKey)
                val iv = cipher.iv
                val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
                val ivB64 = Base64.encodeToString(iv, Base64.NO_WRAP)
                val encB64 = Base64.encodeToString(encrypted, Base64.NO_WRAP)
                "$ivB64:$encB64"
            } catch (_: Exception) {
                null
            }
        }

        private fun decryptToken(payload: String?): String? {
            if (payload.isNullOrBlank()) return null
            val parts = payload.split(":")
            if (parts.size != 2) return null
            return try {
                val secretKey = getOrCreateSecretKey() ?: return null
                val iv = Base64.decode(parts[0], Base64.NO_WRAP)
                val cipherBytes = Base64.decode(parts[1], Base64.NO_WRAP)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))
                String(cipher.doFinal(cipherBytes), Charsets.UTF_8)
            } catch (_: Exception) {
                null
            }
        }

        fun saveServiceConfig(
            context: Context,
            baseUrl: String,
            apiToken: String,
            enabled: Boolean
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val encrypted = encryptToken(apiToken)
            val editor = prefs.edit()
                .putString(KEY_BASE_URL, baseUrl)
                .putBoolean(KEY_ENABLED, enabled)
                .remove(LEGACY_KEY_API_TOKEN)
            if (encrypted != null) {
                editor.putString(KEY_API_TOKEN_ENC, encrypted)
            } else {
                editor.remove(KEY_API_TOKEN_ENC)
            }
            editor.apply()
        }

        fun clearServiceConfig(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_ENABLED, false)
                .remove(KEY_API_TOKEN_ENC)
                .remove(LEGACY_KEY_API_TOKEN)
                .apply()
        }

        fun readDecryptedToken(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enc = prefs.getString(KEY_API_TOKEN_ENC, null)
            if (!enc.isNullOrBlank()) {
                return decryptToken(enc)
            }
            // Migrasi otomatis bila masih ada token lama yang belum terenkripsi
            val legacy = prefs.getString(LEGACY_KEY_API_TOKEN, null)?.trim()
            if (!legacy.isNullOrEmpty()) {
                val newEnc = encryptToken(legacy)
                val editor = prefs.edit().remove(LEGACY_KEY_API_TOKEN)
                if (newEnc != null) editor.putString(KEY_API_TOKEN_ENC, newEnc)
                editor.apply()
                return legacy
            }
            return null
        }

        fun markCallDismissed(context: Context, alertId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val current = getDismissedSet(context).toMutableSet()
            current.add(alertId)
            prefs.edit().putString(KEY_DISMISSED_CALLS, current.joinToString(",")).apply()
        }

        fun getDismissedSet(context: Context): Set<Int> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_DISMISSED_CALLS, "") ?: ""
            if (raw.isBlank()) return emptySet()
            return raw.split(",")
                .mapNotNull { it.trim().toIntOrNull() }
                .toSet()
        }

        fun saveSyncState(
            context: Context,
            knownAlerts: Map<String, String>,
            dismissedIds: List<Int>
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val mergedDismissed = getDismissedSet(context).toMutableSet()
            mergedDismissed.addAll(dismissedIds)

            val jsonObj = JSONObject()
            for ((k, v) in knownAlerts) {
                jsonObj.put(k, v)
            }
            prefs.edit()
                .putString(KEY_KNOWN_ALERTS, jsonObj.toString())
                .putString(KEY_DISMISSED_CALLS, mergedDismissed.joinToString(","))
                .apply()
        }
    }

    private var scheduler: ScheduledExecutorService? = null

    override fun onCreate() {
        super.onCreate()
        CallRingtoneManager.ensureChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        CallRingtoneManager.ensureChannels(this)
        val notification = buildForegroundNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    FG_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(FG_NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
        }

        startPollingLoop()
        return START_STICKY
    }

    override fun onDestroy() {
        stopPollingLoop()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CallRingtoneManager.FG_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle("ProxView Diskominfo Subang")
            .setContentText("Pemantauan insiden & panggilan darurat aktif di latar belakang")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun startPollingLoop() {
        if (scheduler != null && !scheduler!!.isShutdown) return
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleWithFixedDelay(
            {
                try {
                    if (!MainActivity.isAppInForeground) {
                        pollActiveAlertsInBackground()
                    }
                } catch (_: Exception) {
                }
            },
            5L,
            15L,
            TimeUnit.SECONDS
        )
    }

    private fun stopPollingLoop() {
        try {
            scheduler?.shutdownNow()
        } catch (_: Exception) {
        } finally {
            scheduler = null
        }
    }

    private fun pollActiveAlertsInBackground() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val tempWakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ProxView:TempPollWakeLock"
        ).apply { setReferenceCounted(false) }

        try {
            // WakeLock sementara dengan batas waktu 10 detik agar CPU tetap bisa masuk Doze Mode
            tempWakeLock.acquire(10_000L)

            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, false)
            val baseUrl = prefs.getString(KEY_BASE_URL, null)?.trim()
            val token = readDecryptedToken(this)?.trim()

            if (!enabled || baseUrl.isNullOrEmpty() || token.isNullOrEmpty()) return

            val responseStr = fetchAlertsJson(baseUrl, token) ?: return
            val root = JSONObject(responseStr)
            if (!root.optBoolean("success", false)) return

            val dataArray = root.optJSONArray("data") ?: return

            val knownJsonStr = prefs.getString(KEY_KNOWN_ALERTS, "{}") ?: "{}"
            val knownObj = try {
                JSONObject(knownJsonStr)
            } catch (_: Exception) {
                JSONObject()
            }
            val dismissedSet = getDismissedSet(this)

            val currentIds = mutableSetOf<String>()
            var activeCallStillPresent = false

            for (i in 0 until dataArray.length()) {
                val item = dataArray.optJSONObject(i) ?: continue
                val id = item.optInt("id", -1)
                if (id <= 0) continue
                val idKey = id.toString()
                currentIds.add(idKey)

                val severity = item.optString("severity", "WARNING").trim()
                val targetType = item.optString("target_type", "SYSTEM").trim()
                val targetName = item.optString("target_name", "Target").trim()
                val message = item.optString("message", "Terdeteksi gangguan sistem").trim()
                val actionType = item.optString("action_type", "Pesan").trim()
                val handlerCount = item.optInt("handler_count", 0)
                val technicians = item.optString("technicians", "").trim()
                val isBeingHandled = handlerCount > 0 || technicians.isNotEmpty()
                val isCall = actionType.equals("call", ignoreCase = true)

                val prevSeverity = if (knownObj.has(idKey)) knownObj.optString(idKey) else null
                val isNewOrChanged = prevSeverity == null || !prevSeverity.equals(severity, ignoreCase = true)
                knownObj.put(idKey, severity)

                if (isCall && !isBeingHandled && !severity.equals("RECOVERED", ignoreCase = true) && !dismissedSet.contains(id)) {
                    activeCallStillPresent = true
                    if (isNewOrChanged) {
                        CallRingtoneManager.triggerIncomingCall(
                            context = this,
                            alertId = id,
                            severity = severity,
                            targetType = targetType,
                            targetName = targetName,
                            message = message,
                            launchActivityIfBackground = true
                        )
                    }
                } else if (isNewOrChanged) {
                    CallRingtoneManager.showStandardAlertNotification(
                        context = this,
                        alertId = id,
                        severity = severity,
                        targetName = targetName,
                        message = message
                    )
                }
            }

            // Jika semua panggilan darurat sudah RECOVERED atau sudah ditangani teknisi lain, hentikan dering
            if (!activeCallStillPresent) {
                CallRingtoneManager.stopRingtoneAndVibrationOnly()
            }

            // Bersihkan ID alert yang sudah tidak aktif dari knownObj
            val keysToRemove = mutableListOf<String>()
            val keysIter = knownObj.keys()
            while (keysIter.hasNext()) {
                val k = keysIter.next()
                if (!currentIds.contains(k)) {
                    keysToRemove.add(k)
                }
            }
            for (k in keysToRemove) {
                knownObj.remove(k)
            }

            prefs.edit().putString(KEY_KNOWN_ALERTS, knownObj.toString()).apply()
        } finally {
            try {
                if (tempWakeLock.isHeld) {
                    tempWakeLock.release()
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun fetchAlertsJson(baseUrl: String, token: String): String? {
        val cleanBase = baseUrl.trimEnd('/')
        val primaryUrl = "$cleanBase/alerts/active"
        val res = executeGet(primaryUrl, token)
        if (res != null) return res

        // Fallback otomatis localhost <-> 10.0.2.2 pada emulator Android
        val altBase = when {
            cleanBase.contains("://localhost") -> cleanBase.replaceFirst("://localhost", "://10.0.2.2")
            cleanBase.contains("://127.0.0.1") -> cleanBase.replaceFirst("://127.0.0.1", "://10.0.2.2")
            cleanBase.contains("://10.0.2.2") -> cleanBase.replaceFirst("://10.0.2.2", "://localhost")
            else -> null
        }
        return if (altBase != null) executeGet("$altBase/alerts/active", token) else null
    }

    private fun executeGet(urlStr: String, token: String): String? {
        var conn: HttpURLConnection? = null
        return try {
            val url = URL(urlStr)
            val expectedHost = url.host ?: ""
            conn = (url.openConnection() as HttpURLConnection).apply {
                if (this is HttpsURLConnection) {
                    configureTargetHttps(this, expectedHost)
                }
                requestMethod = "GET"
                connectTimeout = 6_000
                readTimeout = 8_000
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Authorization", "Bearer $token")
            }
            if (conn.responseCode == 200) {
                BufferedReader(InputStreamReader(conn.inputStream)).use { it.readText() }
            } else {
                null
            }
        } catch (_: Exception) {
            null
        } finally {
            conn?.disconnect()
        }
    }

    private fun configureTargetHttps(conn: HttpsURLConnection, expectedHost: String) {
        try {
            val targetHostLower = expectedHost.trim().lowercase()
            if (targetHostLower.isEmpty()) return

            val selfSignedTargetTrust = arrayOf<TrustManager>(
                object : X509TrustManager {
                    override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                    override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                        if (chain.isEmpty()) throw java.security.cert.CertificateException("Empty certificate chain")
                    }
                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                }
            )
            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(null, selfSignedTargetTrust, SecureRandom())
            conn.sslSocketFactory = sslContext.socketFactory
            conn.hostnameVerifier = HostnameVerifier { hostname, _ ->
                val actual = hostname?.trim()?.lowercase() ?: ""
                actual == targetHostLower ||
                    (targetHostLower in setOf("localhost", "127.0.0.1", "10.0.2.2") &&
                        actual in setOf("localhost", "127.0.0.1", "10.0.2.2"))
            }
        } catch (_: Exception) {
        }
    }
}
