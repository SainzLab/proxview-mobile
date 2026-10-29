package com.example.proxview

import android.app.AlarmManager
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
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
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLException
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class MonitoringForegroundService : Service() {
    companion object {
        private const val TAG = "ProxViewBgService"
        const val PREFS_NAME = "proxview_bg_prefs"
        const val KEY_BASE_URL = "base_url"
        const val KEY_API_TOKEN_ENC = "api_token_enc"
        const val KEY_BACKUP_TOKEN_ENC = "backup_token_enc"
        private const val LEGACY_KEY_API_TOKEN = "api_token"
        const val KEY_ENABLED = "enabled"
        const val KEY_KNOWN_ALERTS = "known_alerts_json"
        const val KEY_DISMISSED_CALLS = "dismissed_calls_csv"
        const val KEY_LAST_POLL_TIME = "last_poll_time"
        const val KEY_LAST_POLL_STATUS = "last_poll_status"
        const val KEY_LAST_HTTP_CODE = "last_http_code"
        const val KEY_LAST_ACTIVE_COUNT = "last_active_count"
        private const val FG_NOTIFICATION_ID = 99001
        private const val ALARM_REQUEST_CODE = 99002
        private const val WATCHDOG_INTERVAL_MS = 45_000L
        private const val KEYSTORE_ALIAS = "ProxViewBgTokenKey"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"

        @Volatile
        var isServiceRunning: Boolean = false

        @Volatile
        private var cachedPlainToken: String? = null

        private val isPollingNow = AtomicBoolean(false)

        private fun JSONObject.optCleanString(key: String, fallback: String = ""): String {
            if (isNull(key)) return fallback
            val raw = optString(key, fallback).trim()
            return if (raw.isEmpty() || raw.equals("null", ignoreCase = true)) fallback else raw
        }

        private fun getOrCreateSecretKey(forceRecreate: Boolean = false): SecretKey? {
            return try {
                val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
                if (forceRecreate) {
                    try {
                        keyStore.deleteEntry(KEYSTORE_ALIAS)
                    } catch (_: Throwable) {
                    }
                } else {
                    val existing = keyStore.getEntry(KEYSTORE_ALIAS, null) as? KeyStore.SecretKeyEntry
                    if (existing != null) return existing.secretKey
                }

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
            } catch (t: Throwable) {
                Log.w(TAG, "KeyStore error: ${t.message}")
                null
            }
        }

        private fun encryptToken(plainText: String): String? {
            if (plainText.isBlank()) return null
            for (recreate in listOf(false, true)) {
                try {
                    val secretKey = getOrCreateSecretKey(forceRecreate = recreate) ?: continue
                    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                    cipher.init(Cipher.ENCRYPT_MODE, secretKey)
                    val iv = cipher.iv
                    val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
                    val ivB64 = Base64.encodeToString(iv, Base64.NO_WRAP)
                    val encB64 = Base64.encodeToString(encrypted, Base64.NO_WRAP)
                    return "$ivB64:$encB64"
                } catch (_: Throwable) {
                }
            }
            return null
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
            } catch (t: Throwable) {
                Log.w(TAG, "Token decrypt failed: ${t.message}")
                null
            }
        }

        private fun obfuscateBackup(plain: String, context: Context): String {
            if (plain.isBlank()) return ""
            return try {
                val key = (context.packageName + "_ProxViewSalt2026").toByteArray(Charsets.UTF_8)
                val input = plain.toByteArray(Charsets.UTF_8)
                val out = ByteArray(input.size)
                for (i in input.indices) {
                    out[i] = (input[i].toInt() xor key[i % key.size].toInt()).toByte()
                }
                Base64.encodeToString(out, Base64.NO_WRAP)
            } catch (_: Throwable) {
                ""
            }
        }

        private fun deobfuscateBackup(payload: String?, context: Context): String? {
            if (payload.isNullOrBlank()) return null
            return try {
                val key = (context.packageName + "_ProxViewSalt2026").toByteArray(Charsets.UTF_8)
                val input = Base64.decode(payload, Base64.NO_WRAP)
                val out = ByteArray(input.size)
                for (i in input.indices) {
                    out[i] = (input[i].toInt() xor key[i % key.size].toInt()).toByte()
                }
                val result = String(out, Charsets.UTF_8).trim()
                if (result.isNotEmpty()) result else null
            } catch (_: Throwable) {
                null
            }
        }

        fun saveServiceConfig(
            context: Context,
            baseUrl: String,
            apiToken: String,
            enabled: Boolean
        ) {
            val cleanUrl = baseUrl.trim()
            val cleanToken = apiToken.trim()
            cachedPlainToken = if (enabled && cleanToken.isNotEmpty()) cleanToken else null

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val encrypted = encryptToken(cleanToken)
            val backup = if (cleanToken.isNotEmpty()) obfuscateBackup(cleanToken, context) else ""
            val editor = prefs.edit()
                .putString(KEY_BASE_URL, cleanUrl)
                .putBoolean(KEY_ENABLED, enabled)
                .remove(LEGACY_KEY_API_TOKEN)
            if (encrypted != null) {
                editor.putString(KEY_API_TOKEN_ENC, encrypted)
            } else if (!enabled || cleanToken.isEmpty()) {
                editor.remove(KEY_API_TOKEN_ENC)
            }
            if (backup.isNotEmpty()) {
                editor.putString(KEY_BACKUP_TOKEN_ENC, backup)
            } else {
                editor.remove(KEY_BACKUP_TOKEN_ENC)
            }
            editor.apply()

            if (enabled && cleanUrl.isNotEmpty() && cleanToken.isNotEmpty()) {
                scheduleWatchdogAlarm(context.applicationContext)
            } else {
                cancelWatchdogAlarm(context.applicationContext)
            }
        }

        fun clearServiceConfig(context: Context) {
            cachedPlainToken = null
            cancelWatchdogAlarm(context.applicationContext)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean(KEY_ENABLED, false)
                .remove(KEY_API_TOKEN_ENC)
                .remove(KEY_BACKUP_TOKEN_ENC)
                .remove(LEGACY_KEY_API_TOKEN)
                .putString(KEY_LAST_POLL_STATUS, "Sesi Berakhir / Logout")
                .apply()
        }

        fun isMonitoringEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, false)
            val baseUrl = prefs.getString(KEY_BASE_URL, null)?.trim()
            val hasToken = !cachedPlainToken.isNullOrBlank() ||
                    !prefs.getString(KEY_API_TOKEN_ENC, null).isNullOrBlank() ||
                    !prefs.getString(KEY_BACKUP_TOKEN_ENC, null).isNullOrBlank() ||
                    !prefs.getString(LEGACY_KEY_API_TOKEN, null).isNullOrBlank()
            return enabled && !baseUrl.isNullOrEmpty() && hasToken
        }

        fun readDecryptedToken(context: Context): String? {
            val inMemory = cachedPlainToken
            if (!inMemory.isNullOrBlank()) return inMemory

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enc = prefs.getString(KEY_API_TOKEN_ENC, null)
            if (!enc.isNullOrBlank()) {
                val dec = decryptToken(enc)?.trim()
                if (!dec.isNullOrEmpty()) {
                    cachedPlainToken = dec
                    return dec
                }
            }

            // Fallback fail-safe backup token jika KeyStore hardware sedang tertidur/terkunci oleh OS OEM
            val backup = prefs.getString(KEY_BACKUP_TOKEN_ENC, null)
            if (!backup.isNullOrBlank()) {
                val decBackup = deobfuscateBackup(backup, context)?.trim()
                if (!decBackup.isNullOrEmpty()) {
                    cachedPlainToken = decBackup
                    return decBackup
                }
            }

            // Migrasi otomatis bila masih ada token lama yang belum terenkripsi
            val legacy = prefs.getString(LEGACY_KEY_API_TOKEN, null)?.trim()
            if (!legacy.isNullOrEmpty()) {
                cachedPlainToken = legacy
                val newEnc = encryptToken(legacy)
                val newBackup = obfuscateBackup(legacy, context)
                val editor = prefs.edit().remove(LEGACY_KEY_API_TOKEN)
                if (newEnc != null) editor.putString(KEY_API_TOKEN_ENC, newEnc)
                if (newBackup.isNotEmpty()) editor.putString(KEY_BACKUP_TOKEN_ENC, newBackup)
                editor.apply()
                return legacy
            }
            return null
        }

        fun getDiagnostics(context: Context): Map<String, Any?> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean(KEY_ENABLED, false)
            val baseUrl = prefs.getString(KEY_BASE_URL, "") ?: ""
            val hasToken = !readDecryptedToken(context).isNullOrBlank()
            val lastPollTime = prefs.getLong(KEY_LAST_POLL_TIME, 0L)
            val lastPollStatus = prefs.getString(KEY_LAST_POLL_STATUS, "Belum ada polling") ?: "Belum ada polling"
            val lastHttpCode = prefs.getInt(KEY_LAST_HTTP_CODE, 0)
            val lastActiveCount = prefs.getInt(KEY_LAST_ACTIVE_COUNT, 0)

            return mapOf(
                "isServiceRunning" to isServiceRunning,
                "isEnabled" to enabled,
                "hasToken" to hasToken,
                "baseUrl" to baseUrl,
                "lastPollTime" to lastPollTime,
                "lastPollStatus" to lastPollStatus,
                "lastHttpCode" to lastHttpCode,
                "lastActiveCount" to lastActiveCount
            )
        }

        fun scheduleWatchdogAlarm(context: Context, delayMs: Long = WATCHDOG_INTERVAL_MS) {
            try {
                val appCtx = context.applicationContext
                val am = appCtx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val alarmIntent = Intent(appCtx, MonitoringAlarmReceiver::class.java).apply {
                    action = MonitoringAlarmReceiver.ACTION_ALARM_POLL
                }
                val pi = PendingIntent.getBroadcast(
                    appCtx,
                    ALARM_REQUEST_CODE,
                    alarmIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val triggerAt = SystemClock.elapsedRealtime() + delayMs

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (am.canScheduleExactAlarms()) {
                        am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                    } else {
                        am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                    }
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                } else {
                    am.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to schedule watchdog alarm: ${t.message}")
            }
        }

        fun cancelWatchdogAlarm(context: Context) {
            try {
                val appCtx = context.applicationContext
                val am = appCtx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val alarmIntent = Intent(appCtx, MonitoringAlarmReceiver::class.java).apply {
                    action = MonitoringAlarmReceiver.ACTION_ALARM_POLL
                }
                val pi = PendingIntent.getBroadcast(
                    appCtx,
                    ALARM_REQUEST_CODE,
                    alarmIntent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                )
                if (pi != null) {
                    am.cancel(pi)
                    pi.cancel()
                }
            } catch (_: Throwable) {
            }
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

        fun getKnownAlertsMap(context: Context): Map<String, String> {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_KNOWN_ALERTS, "{}") ?: "{}"
            val result = mutableMapOf<String, String>()
            try {
                val obj = JSONObject(raw)
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    val v = obj.optCleanString(k, "")
                    if (k.isNotEmpty() && v.isNotEmpty()) {
                        result[k] = v
                    }
                }
            } catch (_: Throwable) {
            }
            return result
        }

        fun saveSyncState(
            context: Context,
            knownAlerts: Map<String, String>,
            dismissedIds: List<Int>,
            overwriteKnownAlerts: Boolean = true
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val mergedDismissed = getDismissedSet(context).toMutableSet()
            mergedDismissed.addAll(dismissedIds)

            val editor = prefs.edit()
            if (overwriteKnownAlerts) {
                val jsonObj = JSONObject()
                val activeIntIds = mutableSetOf<Int>()
                for ((k, v) in knownAlerts) {
                    jsonObj.put(k, v)
                    k.toIntOrNull()?.let { activeIntIds.add(it) }
                }
                // Pertahankan ID dismissed hanya untuk alert yang masih aktif agar tidak menumpuk selamanya
                mergedDismissed.retainAll(activeIntIds)
                editor.putString(KEY_KNOWN_ALERTS, jsonObj.toString())
            }

            editor.putString(KEY_DISMISSED_CALLS, mergedDismissed.joinToString(",")).apply()
        }

        private data class HttpFetchResult(
            val httpCode: Int,
            val body: String?,
            val error: String? = null
        )

        fun pollOnce(context: Context) {
            if (MainActivity.isAppInForeground) return
            if (!isPollingNow.compareAndSet(false, true)) return

            val appCtx = context.applicationContext
            val pm = appCtx.getSystemService(Context.POWER_SERVICE) as PowerManager
            val tempWakeLock = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ProxView:TempPollWakeLock"
            ).apply { setReferenceCounted(false) }

            try {
                // WakeLock sementara selama request berlangsung agar CPU tidak tidur di tengah koneksi
                tempWakeLock.acquire(25_000L)

                val prefs = appCtx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val enabled = prefs.getBoolean(KEY_ENABLED, false)
                val baseUrl = prefs.getString(KEY_BASE_URL, null)?.trim()
                val token = readDecryptedToken(appCtx)?.trim()

                if (!enabled) {
                    prefs.edit()
                        .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                        .putString(KEY_LAST_POLL_STATUS, "Pemantauan dinonaktifkan")
                        .apply()
                    return
                }
                if (baseUrl.isNullOrEmpty()) {
                    prefs.edit()
                        .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                        .putString(KEY_LAST_POLL_STATUS, "URL server belum disetel")
                        .apply()
                    return
                }
                if (token.isNullOrEmpty()) {
                    prefs.edit()
                        .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                        .putString(KEY_LAST_POLL_STATUS, "Token API kosong / sesi kedaluwarsa")
                        .apply()
                    return
                }

                val fetchResult = fetchAlertsJson(baseUrl, token)
                val responseStr = fetchResult.body

                if (responseStr.isNullOrBlank()) {
                    prefs.edit()
                        .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                        .putInt(KEY_LAST_HTTP_CODE, fetchResult.httpCode)
                        .putString(
                            KEY_LAST_POLL_STATUS,
                            if (fetchResult.httpCode > 0) "HTTP ${fetchResult.httpCode}: ${fetchResult.error ?: "Gagal terhubung"}"
                            else "Gagal koneksi: ${fetchResult.error ?: "Server tidak dapat dijangkau"}"
                        )
                        .apply()
                    return
                }

                val root = JSONObject(responseStr)
                if (!root.optBoolean("success", false)) {
                    val errMsg = root.optCleanString("message", "Respon server tidak valid")
                    prefs.edit()
                        .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                        .putInt(KEY_LAST_HTTP_CODE, fetchResult.httpCode)
                        .putString(KEY_LAST_POLL_STATUS, "API Error: $errMsg")
                        .apply()
                    return
                }

                val dataArray = root.optJSONArray("data") ?: org.json.JSONArray()

                val knownJsonStr = prefs.getString(KEY_KNOWN_ALERTS, "{}") ?: "{}"
                val knownObj = try {
                    JSONObject(knownJsonStr)
                } catch (_: Throwable) {
                    JSONObject()
                }
                val dismissedSet = getDismissedSet(appCtx).toMutableSet()

                val currentIds = mutableSetOf<String>()
                val currentIntIds = mutableSetOf<Int>()
                var activeCallStillPresent = false

                for (i in 0 until dataArray.length()) {
                    val item = dataArray.optJSONObject(i) ?: continue
                    val id = item.optInt("id", -1)
                    if (id <= 0) continue

                    val isResolved = item.optInt("is_resolved", 0) == 1 ||
                            item.optBoolean("is_resolved", false)
                    if (isResolved) continue

                    val idKey = id.toString()
                    currentIds.add(idKey)
                    currentIntIds.add(id)

                    val severity = item.optCleanString("severity", "WARNING")
                    val targetType = item.optCleanString("target_type", "SYSTEM")
                    val targetName = item.optCleanString("target_name", "Target")
                    val message = item.optCleanString("message", "Terdeteksi gangguan sistem")
                    val actionType = item.optCleanString("action_type", "Pesan")
                    val handlerCount = item.optInt("handler_count", 0)
                    val technicians = item.optCleanString("technicians", "")
                    val isBeingHandled = handlerCount > 0 ||
                            (technicians.isNotEmpty() && technicians != "-")
                    val isCall = actionType.equals("call", ignoreCase = true)

                    val prevSeverity = if (knownObj.has(idKey)) {
                        knownObj.optCleanString(idKey, "")
                    } else {
                        ""
                    }
                    val isNewOrChanged = prevSeverity.isEmpty() ||
                            !prevSeverity.equals(severity, ignoreCase = true)
                    knownObj.put(idKey, severity)

                    val isUnhandledCall = isCall &&
                            !isBeingHandled &&
                            !severity.equals("RECOVERED", ignoreCase = true) &&
                            !dismissedSet.contains(id)

                    // Jika alert ini sebelumnya sedang berdering namun sekarang sudah ditangani / RECOVERED
                    if (!isUnhandledCall && CallRingtoneManager.isRingingFor(id)) {
                        CallRingtoneManager.stopCallRingtone(appCtx, id)
                    }

                    if (isUnhandledCall) {
                        activeCallStillPresent = true
                        if (isNewOrChanged || !CallRingtoneManager.isCurrentlyRinging()) {
                            Log.i(TAG, "Triggering incoming emergency call for alert #$id [$severity] $targetName")
                            CallRingtoneManager.triggerIncomingCall(
                                context = appCtx,
                                alertId = id,
                                severity = severity,
                                targetType = targetType,
                                targetName = targetName,
                                message = message,
                                launchActivityIfBackground = true
                            )
                        }
                    } else if (isNewOrChanged) {
                        Log.i(TAG, "Showing standard alert notification for alert #$id [$severity] $targetName")
                        CallRingtoneManager.showStandardAlertNotification(
                            context = appCtx,
                            alertId = id,
                            severity = severity,
                            targetName = targetName,
                            message = message
                        )
                    }
                }

                // Jika semua panggilan darurat sudah RECOVERED atau sudah ditangani teknisi lain, hentikan dering
                if (!activeCallStillPresent && CallRingtoneManager.isCurrentlyRinging()) {
                    CallRingtoneManager.stopCallRingtone(appCtx, null)
                }

                // Bersihkan ID alert yang sudah selesai dari knownObj dan dismissedSet
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
                dismissedSet.retainAll(currentIntIds)

                val statusText = if (currentIntIds.isEmpty()) {
                    "200 OK (Normal, 0 gangguan)"
                } else if (activeCallStillPresent) {
                    "200 OK (${currentIntIds.size} gangguan, PANGGILAN AKTIF)"
                } else {
                    "200 OK (${currentIntIds.size} gangguan aktif)"
                }

                prefs.edit()
                    .putString(KEY_KNOWN_ALERTS, knownObj.toString())
                    .putString(KEY_DISMISSED_CALLS, dismissedSet.joinToString(","))
                    .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                    .putInt(KEY_LAST_HTTP_CODE, fetchResult.httpCode)
                    .putInt(KEY_LAST_ACTIVE_COUNT, currentIntIds.size)
                    .putString(KEY_LAST_POLL_STATUS, statusText)
                    .apply()
            } catch (t: Throwable) {
                Log.e(TAG, "Background poll error: ${t.message}", t)
                try {
                    val prefs = appCtx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putLong(KEY_LAST_POLL_TIME, System.currentTimeMillis())
                        .putString(KEY_LAST_POLL_STATUS, "Error: ${t.javaClass.simpleName} (${t.message})")
                        .apply()
                } catch (_: Throwable) {
                }
            } finally {
                isPollingNow.set(false)
                try {
                    if (tempWakeLock.isHeld) {
                        tempWakeLock.release()
                    }
                } catch (_: Throwable) {
                }
            }
        }

        private fun fetchAlertsJson(baseUrl: String, token: String): HttpFetchResult {
            val cleanBase = baseUrl.trimEnd('/')
            val primaryUrl = "$cleanBase/alerts/active"
            val res = executeGet(primaryUrl, token)
            if (res.httpCode == 200 && !res.body.isNullOrBlank()) return res

            // Fallback otomatis localhost <-> 10.0.2.2 pada emulator Android
            val altBase = when {
                cleanBase.contains("://localhost") -> cleanBase.replaceFirst("://localhost", "://10.0.2.2")
                cleanBase.contains("://127.0.0.1") -> cleanBase.replaceFirst("://127.0.0.1", "://10.0.2.2")
                cleanBase.contains("://10.0.2.2") -> cleanBase.replaceFirst("://10.0.2.2", "://localhost")
                else -> null
            }
            if (altBase != null) {
                val altRes = executeGet("$altBase/alerts/active", token)
                if (altRes.httpCode == 200 && !altRes.body.isNullOrBlank()) return altRes
            }
            return res
        }

        private fun executeGet(urlStr: String, token: String): HttpFetchResult {
            return try {
                // Gunakan TLS bawaan sistem terlebih dahulu (optimal untuk Cloudflare / Let's Encrypt / TLS 1.3 + SNI)
                performHttpGet(urlStr, token, trustSelfSignedForTarget = false)
            } catch (sslEx: SSLException) {
                Log.w(TAG, "Standard TLS failed for $urlStr (${sslEx.message}), retrying with target self-signed trust")
                try {
                    performHttpGet(urlStr, token, trustSelfSignedForTarget = true)
                } catch (e: Throwable) {
                    Log.w(TAG, "Self-signed TLS fallback failed for $urlStr: ${e.message}")
                    HttpFetchResult(0, null, "SSL Error: ${e.message}")
                }
            } catch (t: Throwable) {
                Log.w(TAG, "HTTP GET failed for $urlStr: ${t.javaClass.simpleName}: ${t.message}")
                HttpFetchResult(0, null, "${t.javaClass.simpleName}: ${t.message}")
            }
        }

        private fun performHttpGet(
            urlStr: String,
            token: String,
            trustSelfSignedForTarget: Boolean
        ): HttpFetchResult {
            var conn: HttpURLConnection? = null
            return try {
                val url = URL(urlStr)
                val expectedHost = url.host ?: ""
                conn = (url.openConnection() as HttpURLConnection).apply {
                    if (this is HttpsURLConnection && trustSelfSignedForTarget) {
                        configureTargetHttps(this, expectedHost)
                    }
                    requestMethod = "GET"
                    instanceFollowRedirects = true
                    useCaches = false
                    connectTimeout = 10_000
                    readTimeout = 12_000
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("Cache-Control", "no-cache")
                    setRequestProperty("User-Agent", "ProxView-Mobile/1.0 (Android)")
                    setRequestProperty("Authorization", "Bearer $token")
                }
                val status = conn.responseCode
                if (status == 200) {
                    val text = BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { it.readText() }
                    HttpFetchResult(status, text)
                } else {
                    val errStream = conn.errorStream
                    val errText = if (errStream != null) {
                        try {
                            BufferedReader(InputStreamReader(errStream, Charsets.UTF_8)).use { it.readText() }
                        } catch (_: Throwable) {
                            null
                        }
                    } else {
                        null
                    }
                    Log.w(TAG, "Non-200 status ($status) from $urlStr: $errText")
                    HttpFetchResult(status, null, errText ?: "HTTP $status")
                }
            } finally {
                try {
                    conn?.disconnect()
                } catch (_: Throwable) {
                }
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
            } catch (_: Throwable) {
            }
        }
    }

    private var scheduler: ScheduledExecutorService? = null

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        CallRingtoneManager.ensureChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isServiceRunning = true
        CallRingtoneManager.ensureChannels(this)

        if (!isMonitoringEnabled(this)) {
            stopPollingLoop()
            cancelWatchdogAlarm(this)
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildForegroundNotification()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                try {
                    startForeground(
                        FG_NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or
                                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } catch (_: Throwable) {
                    startForeground(
                        FG_NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    FG_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(FG_NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startForeground error: ${t.message}")
        }

        scheduleWatchdogAlarm(this)
        startPollingLoop()

        if (intent?.action == MonitoringAlarmReceiver.ACTION_ALARM_POLL) {
            triggerImmediateAsyncPoll()
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Saat user melakukan swipe-close aplikasi dari Recent Apps:
        // Pastikan status foreground di-reset ke false & jadwalkan alarm pemulihan cepat
        MainActivity.isAppInForeground = false
        if (isMonitoringEnabled(this)) {
            scheduleWatchdogAlarm(this, delayMs = 2_500L)
            startPollingLoop()
            triggerImmediateAsyncPoll()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "FGS timeout for fgsType=$fgsType, scheduling watchdog wakeup")
        if (isMonitoringEnabled(this)) {
            scheduleWatchdogAlarm(this, delayMs = 5_000L)
        }
    }

    override fun onTimeout(startId: Int) {
        if (isMonitoringEnabled(this)) {
            scheduleWatchdogAlarm(this, delayMs = 5_000L)
        }
    }

    override fun onDestroy() {
        isServiceRunning = false
        stopPollingLoop()
        if (isMonitoringEnabled(this)) {
            scheduleWatchdogAlarm(this, delayMs = 5_000L)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildForegroundNotification(): Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = CallRingtoneManager.buildActivityPendingIntent(
            this,
            0,
            openIntent
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

    private fun triggerImmediateAsyncPoll() {
        val exec = scheduler
        if (exec != null && !exec.isShutdown) {
            exec.execute {
                try {
                    if (!MainActivity.isAppInForeground) {
                        pollOnce(applicationContext)
                    }
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun startPollingLoop() {
        if (scheduler != null && !scheduler!!.isShutdown) return
        scheduler = Executors.newSingleThreadScheduledExecutor()
        scheduler?.scheduleWithFixedDelay(
            {
                try {
                    scheduleWatchdogAlarm(applicationContext)
                    if (!MainActivity.isAppInForeground) {
                        pollOnce(applicationContext)
                    }
                } catch (_: Throwable) {
                    // Tangkap semua Throwable agar ScheduledExecutorService tidak pernah berhenti diam-diam
                }
            },
            2L,
            10L,
            TimeUnit.SECONDS
        )
    }

    private fun stopPollingLoop() {
        try {
            scheduler?.shutdownNow()
        } catch (_: Throwable) {
        } finally {
            scheduler = null
        }
    }
}
