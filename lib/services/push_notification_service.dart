import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'notification_service.dart';

/// Payload data-only FCM yang dikirim oleh backend
/// (`monitoringDaemon.js#triggerAlert` dan `authController.js#simulateFCM`).
///
/// Contoh:
/// ```json
/// { "alert_id": "42" | "TEST-000", "target_name": "...", "severity": "DOWN",
///   "action_type": "Call" | "Pesan", "message": "...",
///   "click_action": "FLUTTER_NOTIFICATION_CLICK" }
/// ```
class AlertPushPayload {
  /// Nilai mentah `alert_id` (bisa numerik atau string simulasi seperti `TEST-000`).
  final String rawAlertId;

  /// ID tiket `active_alerts` di database. `null` bila payload adalah simulasi.
  final int? alertId;
  final String targetName;
  final String severity;
  final String actionType;
  final String message;

  const AlertPushPayload({
    required this.rawAlertId,
    required this.alertId,
    required this.targetName,
    required this.severity,
    required this.actionType,
    required this.message,
  });

  factory AlertPushPayload.fromData(Map<String, dynamic> data) {
    String read(String key, String fallback) {
      final v = data[key]?.toString().trim() ?? '';
      return v.isEmpty ? fallback : v;
    }

    final raw = read('alert_id', '');
    return AlertPushPayload(
      rawAlertId: raw,
      alertId: int.tryParse(raw),
      targetName: read('target_name', 'Monitoring Alert'),
      severity: read('severity', 'WARNING').toUpperCase(),
      actionType: read('action_type', 'Pesan'),
      message: read('message', ''),
    );
  }

  /// Payload dianggap milik ProxView bila minimal memiliki `alert_id` atau `action_type`.
  static bool isProxViewPayload(Map<String, dynamic> data) =>
      data.containsKey('alert_id') || data.containsKey('action_type');

  bool get isCall => actionType.toLowerCase() == 'call';

  /// `true` untuk payload uji coba dari Web Admin (alert_id non-numerik, mis. `TEST-000`).
  bool get isSimulation => alertId == null;

  /// ID notifikasi lokal harus `int` 32-bit; ID simulasi di-hash agar tidak melempar FormatException.
  int get notificationId => alertId ?? (rawAlertId.hashCode & 0x7fffffff);

  /// ID unik panggilan CallKit.
  String get callId => rawAlertId.isNotEmpty
      ? 'proxview-$rawAlertId'
      : 'proxview-${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> toExtra() => <String, dynamic>{
        'alert_id': rawAlertId,
        'target_name': targetName,
        'severity': severity,
        'action_type': actionType,
        'message': message,
      };
}

/// Entry point FCM saat aplikasi berada di background / terminated.
/// Wajib top-level function + `vm:entry-point` agar tidak di-tree-shake.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (!AlertPushPayload.isProxViewPayload(message.data)) return;
  final payload = AlertPushPayload.fromData(message.data);
  await PushNotificationService.presentPayload(payload);
}

/// Mengelola siklus hidup FCM token, listener foreground FCM, dan event CallKit.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static const Duration _tokenTimeout = Duration(seconds: 5);

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<CallEvent?>? _callEventSub;
  bool _listening = false;
  int? _pendingAcceptedAlertId;

  /// Dipanggil saat FCM alert nyata (bukan simulasi) diterima di foreground.
  /// Diisi oleh MainShellView untuk memicu sinkronisasi AlertIncidentViewModel.
  ValueChanged<AlertPushPayload>? onForegroundAlert;

  /// Dipanggil saat teknisi menolak panggilan CallKit untuk alert nyata.
  ValueChanged<int>? onEmergencyCallDeclined;

  // ===========================================================================
  // FCM TOKEN
  // ===========================================================================

  /// Mengambil FCM registration token dengan batas waktu agar tombol login tidak hang
  /// di perangkat tanpa Google Play Services / jaringan yang memblokir FCM.
  ///
  /// Catatan: `getToken()` ditandai deprecated di firebase_messaging 17 dengan pengganti
  /// `register()/onRegistered`. API pengganti mengembalikan Firebase Installation ID (FID),
  /// BUKAN registration token yang diharapkan `sendEachForMulticast()` di backend,
  /// sehingga migrasi harus dilakukan bersamaan dengan perubahan backend.
  Future<String?> fetchToken() async {
    if (kIsWeb) return null;
    try {
      final token = await FirebaseMessaging.instance
          // ignore: deprecated_member_use
          .getToken()
          .timeout(_tokenTimeout);
      final trimmed = token?.trim();
      return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    } catch (e) {
      debugPrint('[FCM] Gagal mengambil token: $e');
      return null;
    }
  }

  /// Mencabut token di sisi Firebase saat logout / sesi dicabut sehingga perangkat
  /// berhenti menerima panggilan darurat meski backend masih menyimpan token lama.
  /// Login berikutnya akan menghasilkan token baru yang dikirim ulang ke backend.
  Future<void> revokeToken() async {
    if (kIsWeb) return;
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken().timeout(_tokenTimeout);
    } catch (e) {
      debugPrint('[FCM] Gagal mencabut token: $e');
    }
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
  }

  // ===========================================================================
  // LISTENER (MAIN ISOLATE)
  // ===========================================================================

  /// Memasang listener FCM foreground dan event CallKit. Aman dipanggil berulang kali.
  Future<void> startListening() async {
    if (_listening || kIsWeb) return;
    _listening = true;

    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _callEventSub = FlutterCallkitIncoming.onEvent.listen(
      _handleCallEvent,
      onError: (Object e) => debugPrint('[CALLKIT] Event error: $e'),
    );

    await _recoverAcceptedCallOnColdStart();
  }

  Future<void> stopListening() async {
    await _onMessageSub?.cancel();
    await _callEventSub?.cancel();
    _onMessageSub = null;
    _callEventSub = null;
    _listening = false;
  }

  /// ID alert yang diterima lewat CallKit sebelum MainShellView siap (cold start).
  int? consumePendingAcceptedAlertId() {
    final id = _pendingAcceptedAlertId;
    _pendingAcceptedAlertId = null;
    return id;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!AlertPushPayload.isProxViewPayload(message.data)) return;
    final payload = AlertPushPayload.fromData(message.data);

    // Alert nyata + shell aktif: serahkan ke alur in-app (EmergencyCallView + ringtone native)
    // agar tidak terjadi dering ganda antara CallKit dan EmergencyCallView.
    final handler = onForegroundAlert;
    if (!payload.isSimulation && handler != null) {
      handler(payload);
      return;
    }
    unawaited(presentPayload(payload));
  }

  void _handleCallEvent(CallEvent? event) {
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        unawaited(_onCallAccepted(callKitParams));
      case CallEventActionCallDecline(:final callKitParams):
        unawaited(_onCallDeclined(callKitParams));
      default:
        break;
    }
  }

  Future<void> _onCallAccepted(CallKitParams params) async {
    try {
      await FlutterCallkitIncoming.endCall(params.id);
    } catch (_) {}

    final alertId = _alertIdFromParams(params);
    if (alertId == null) {
      debugPrint('[CALLKIT] Panggilan simulasi diterima: ${params.id}');
      return;
    }

    // Hentikan ringtone native dari MonitoringForegroundService bila ikut berdering.
    unawaited(NotificationService().stopEmergencyCall(alertId));

    final openHandler = NotificationService().onEmergencyAlertOpened;
    if (openHandler != null) {
      openHandler(alertId);
    } else {
      _pendingAcceptedAlertId = alertId;
    }
  }

  Future<void> _onCallDeclined(CallKitParams params) async {
    final alertId = _alertIdFromParams(params);
    if (alertId == null) return;
    unawaited(NotificationService().stopEmergencyCall(alertId));
    onEmergencyCallDeclined?.call(alertId);
  }

  /// Saat aplikasi diluncurkan dari tombol "Tangani" CallKit, event accept bisa terjadi
  /// sebelum listener terpasang. Periksa panggilan aktif yang sudah diterima.
  Future<void> _recoverAcceptedCallOnColdStart() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      for (final call in calls) {
        if (call.isAccepted) {
          await _onCallAccepted(call);
        }
      }
    } catch (e) {
      debugPrint('[CALLKIT] Gagal membaca panggilan aktif: $e');
    }
  }

  static int? _alertIdFromParams(CallKitParams params) {
    final raw = params.extra?['alert_id']?.toString();
    return raw == null ? null : int.tryParse(raw);
  }

  // ===========================================================================
  // PRESENTASI (DIPAKAI MAIN ISOLATE & BACKGROUND ISOLATE)
  // ===========================================================================

  static Future<void> presentPayload(AlertPushPayload payload) async {
    if (payload.isCall) {
      await _showCallKit(payload);
    } else {
      await NotificationService().showDataNotification(
        id: payload.notificationId,
        title: '[${payload.severity}] ${payload.targetName}',
        body: payload.message,
      );
    }
  }

  static Future<void> _showCallKit(AlertPushPayload payload) async {
    final handle = payload.message.isNotEmpty
        ? '[${payload.severity}] ${payload.message}'
        : 'Severity: ${payload.severity}';

    final params = CallKitParams(
      id: payload.callId,
      nameCaller: payload.targetName,
      appName: 'ProxView',
      handle: handle,
      type: 0,
      duration: 30000,
      extra: payload.toExtra(),
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: false,
        isShowFullLockedScreen: true,
        isImportant: true,
        backgroundColor: '#0B0F14',
        actionColor: '#10B981',
        textAccept: 'Tangani',
        textDecline: 'Tolak',
        incomingCallNotificationChannelName: 'Panggilan Darurat Insiden',
        missedCallNotificationChannelName: 'Panggilan Insiden Terlewat',
      ),
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Panggilan insiden terlewat',
      ),
      callingNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Panggilan insiden masuk',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('[CALLKIT] Gagal menampilkan panggilan: $e');
      // Fallback: tetap beri tahu teknisi melalui notifikasi biasa.
      await NotificationService().showDataNotification(
        id: payload.notificationId,
        title: 'PANGGILAN DARURAT: [${payload.severity}] ${payload.targetName}',
        body: payload.message,
      );
    }
  }
}
