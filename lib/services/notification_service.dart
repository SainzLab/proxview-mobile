import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert_incident_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _bgChannel =
      MethodChannel('com.example.proxview/background_monitor');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isAndroidNative => !kIsWeb && Platform.isAndroid;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      await _plugin.initialize(settings);

      // Minta izin runtime Android 13+ (POST_NOTIFICATIONS) & Android 14+ (Full Screen Intent)
      if (_isAndroidNative) {
        final androidPlugin = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
        await androidPlugin?.requestFullScreenIntentPermission();
      }

      _initialized = true;
    } catch (_) {
      // Abaikan jika dijalankan pada environment unit test atau platform tanpa plugin
    }
  }

  /// Menjalankan atau memperbarui Android Foreground Service untuk pemantauan background
  Future<void> configureBackgroundService({
    required String baseUrl,
    required String apiToken,
    required bool enabled,
  }) async {
    if (!_isAndroidNative) return;
    try {
      await _bgChannel.invokeMethod('configureAndStartService', {
        'baseUrl': baseUrl,
        'apiToken': apiToken,
        'enabled': enabled,
      });
    } catch (_) {}
  }

  /// Menghentikan Android Foreground Service & mematikan dering panggilan darurat
  Future<void> stopBackgroundService() async {
    if (!_isAndroidNative) return;
    try {
      await _bgChannel.invokeMethod('stopService');
    } catch (_) {}
  }

  /// Sinkronisasi state alert antara Dart UI dan Background Service Android
  Future<Set<int>> syncAlertState({
    required Map<int, String> knownSeverities,
    required Set<int> dismissedCallIds,
  }) async {
    if (!_isAndroidNative) return dismissedCallIds;
    try {
      final stringKeyMap = <String, String>{
        for (final entry in knownSeverities.entries)
          entry.key.toString(): entry.value,
      };
      final res = await _bgChannel.invokeMethod<List<dynamic>>(
        'syncAlertState',
        {
          'knownAlerts': stringKeyMap,
          'dismissedCallIds': dismissedCallIds.toList(),
        },
      );
      if (res != null) {
        return res.map((e) => (e as num).toInt()).toSet();
      }
    } catch (_) {}
    return dismissedCallIds;
  }

  /// Memicu dering telepon + getaran panggilan darurat (seperti Telepon / WhatsApp)
  Future<void> startEmergencyCall(AlertModel alert) async {
    if (!_initialized) await initialize();
    if (_isAndroidNative) {
      try {
        await _bgChannel.invokeMethod('startCallRingtone', {
          'alertId': alert.id,
          'severity': alert.severity,
          'targetType': alert.targetType,
          'targetName': alert.targetName,
          'message': alert.message,
        });
        return;
      } catch (_) {}
    }
    await _showPluginNotification(alert, isCall: true);
  }

  /// Menghentikan dering telepon, getaran, dan menutup notifikasi panggilan darurat
  Future<void> stopEmergencyCall([int? alertId]) async {
    if (_isAndroidNative) {
      try {
        await _bgChannel.invokeMethod('stopCallRingtone', {
          'alertId': alertId,
        });
      } catch (_) {}
    }
    try {
      if (alertId != null) {
        await _plugin.cancel(alertId);
      }
    } catch (_) {}
  }

  /// Menampilkan notifikasi saat ada gangguan baru atau perubahan severity
  Future<void> showAlertNotification(AlertModel alert) async {
    if (!_initialized) await initialize();
    final isCall = alert.isEmergencyCall &&
        !alert.isBeingHandled &&
        alert.severity.toUpperCase() != 'RECOVERED';

    if (isCall) {
      await startEmergencyCall(alert);
    } else {
      await _showPluginNotification(alert, isCall: false);
    }
  }

  Future<void> _showPluginNotification(
    AlertModel alert, {
    required bool isCall,
  }) async {
    try {
      // Flag 4 = Notification.FLAG_INSISTENT (berdering terus-menerus sampai direspons)
      final insistentFlags = isCall ? Int32List.fromList(<int>[4]) : null;
      final vibration = isCall
          ? Int64List.fromList(<int>[0, 1000, 500, 1000, 500, 1000])
          : Int64List.fromList(<int>[0, 400, 200, 400]);

      final androidDetails = AndroidNotificationDetails(
        isCall ? 'proxview_emergency_call_v2' : 'proxview_alerts_v2',
        isCall ? 'Panggilan Darurat Insiden' : 'Notifikasi Gangguan & Insiden',
        channelDescription:
            'Notifikasi insiden & panggilan darurat sistem ProxView',
        importance: Importance.max,
        priority: Priority.max,
        category: isCall
            ? AndroidNotificationCategory.call
            : AndroidNotificationCategory.alarm,
        fullScreenIntent: isCall,
        ongoing: isCall,
        autoCancel: !isCall,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibration,
        audioAttributesUsage: isCall
            ? AudioAttributesUsage.notificationRingtone
            : AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,
        additionalFlags: insistentFlags,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      await _plugin.show(
        alert.id,
        isCall
            ? 'PANGGILAN DARURAT: [${alert.severity}] ${alert.targetName}'
            : '[${alert.severity}] ${alert.targetName}',
        alert.message,
        details,
      );
    } catch (_) {}
  }
}
