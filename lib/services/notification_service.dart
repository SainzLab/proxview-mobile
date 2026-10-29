import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show VoidCallback, ValueChanged, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert_incident_model.dart';

class InitialNotificationState {
  final Map<int, String> knownSeverities;
  final Set<int> dismissedCallIds;
  final int? emergencyAlertId;
  final bool openAlertsTab;

  const InitialNotificationState({
    this.knownSeverities = const {},
    this.dismissedCallIds = const {},
    this.emergencyAlertId,
    this.openAlertsTab = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _bgChannel =
      MethodChannel('com.example.proxview/background_monitor');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionsRequested = false;

  ValueChanged<int>? onEmergencyAlertOpened;
  VoidCallback? onOpenAlertsTab;

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

      if (_isAndroidNative) {
        _bgChannel.setMethodCallHandler(_handleNativeMethodCall);
      }

      _initialized = true;
    } catch (_) {
      // Abaikan jika dijalankan pada environment unit test atau platform tanpa plugin
    }
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onEmergencyAlertOpened':
        final id = (call.arguments as num?)?.toInt();
        if (id != null && id > 0) {
          onEmergencyAlertOpened?.call(id);
        }
        break;
      case 'onOpenAlertsTab':
        onOpenAlertsTab?.call();
        break;
    }
  }

  /// Meminta izin notifikasi runtime, full-screen call intent (Android 14+), dan pengecualian baterai
  /// secara berurutan setelah MainActivity siap agar tidak saling bertabrakan.
  Future<void> requestRuntimeAndBackgroundPermissions() async {
    if (!_isAndroidNative || _permissionsRequested) return;
    _permissionsRequested = true;
    try {
      if (!_initialized) await initialize();
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await _bgChannel.invokeMethod('requestBackgroundPermissions');
    } catch (_) {}
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
    _permissionsRequested = false;
    try {
      await _bgChannel.invokeMethod('stopService');
    } catch (_) {}
  }

  /// Membaca data diagnostik status polling latar belakang (waktu terakhir, HTTP code, pesan status)
  Future<Map<String, dynamic>> getBackgroundDiagnostics() async {
    if (!_isAndroidNative) return {};
    try {
      final res = await _bgChannel
          .invokeMethod<Map<dynamic, dynamic>>('getBackgroundServiceDiagnostics');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {};
  }

  /// Membuka pengaturan Mulai Otomatis (Auto-start / App Battery Manager) OEM (Realme/Oppo/Xiaomi/Vivo)
  Future<void> openAutoStartSettings() async {
    if (!_isAndroidNative) return;
    try {
      await _bgChannel.invokeMethod('openAutoStartSettings');
    } catch (_) {}
  }

  /// Menjalankan uji coba panggilan darurat dan dering alarm di perangkat
  Future<void> testEmergencyCall() async {
    if (!_isAndroidNative) return;
    try {
      await _bgChannel.invokeMethod('testEmergencyCall');
    } catch (_) {}
  }

  /// Menjalankan uji coba notifikasi biasa dan spanduk heads-up di perangkat
  Future<void> testStandardAlert() async {
    if (!_isAndroidNative) return;
    try {
      await _bgChannel.invokeMethod('testStandardAlert');
    } catch (_) {}
  }

  /// Membaca state awal dari SharedPreferences milik Foreground Service saat aplikasi baru dibuka
  Future<InitialNotificationState> getInitialNotificationState() async {
    if (!_isAndroidNative) return const InitialNotificationState();
    try {
      final raw = await _bgChannel
          .invokeMethod<Map<dynamic, dynamic>>('getInitialNotificationState');
      if (raw == null) return const InitialNotificationState();

      final knownMap = <int, String>{};
      final rawKnown = raw['knownAlerts'];
      if (rawKnown is Map) {
        rawKnown.forEach((k, v) {
          final id = int.tryParse(k.toString());
          final sev = v?.toString() ?? '';
          if (id != null && sev.isNotEmpty) {
            knownMap[id] = sev;
          }
        });
      }

      final dismissedSet = <int>{};
      final rawDismissed = raw['dismissedCallIds'];
      if (rawDismissed is List) {
        for (final item in rawDismissed) {
          if (item is num) dismissedSet.add(item.toInt());
        }
      }

      final emergencyId = (raw['emergencyAlertId'] as num?)?.toInt();
      final openAlertsTab = raw['openAlertsTab'] == true;

      return InitialNotificationState(
        knownSeverities: knownMap,
        dismissedCallIds: dismissedSet,
        emergencyAlertId: emergencyId,
        openAlertsTab: openAlertsTab,
      );
    } catch (_) {
      return const InitialNotificationState();
    }
  }

  /// Sinkronisasi state alert antara Dart UI dan Background Service Android
  Future<Set<int>> syncAlertState({
    required Map<int, String> knownSeverities,
    required Set<int> dismissedCallIds,
    bool overwriteKnown = true,
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
          'overwriteKnown': overwriteKnown,
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
        isCall ? 'proxview_emergency_call_v4' : 'proxview_alerts_v4',
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
