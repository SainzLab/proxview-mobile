import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert_incident_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
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
      _initialized = true;
    } catch (_) {
      // Abaikan jika dijalankan pada environment test atau platform tanpa plugin
    }
  }

  Future<void> showAlertNotification(AlertModel alert) async {
    if (!_initialized) await initialize();
    try {
      final isCall = alert.isEmergencyCall;
      final androidDetails = AndroidNotificationDetails(
        isCall ? 'proxview_emergency_call' : 'proxview_alerts',
        isCall ? 'Emergency Call Alerts' : 'Monitoring Alerts',
        channelDescription: 'Notifikasi insiden & gangguan sistem ProxView',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: isCall,
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
        '[${alert.severity}] ${alert.targetName}',
        alert.message,
        details,
      );
    } catch (_) {}
  }
}
