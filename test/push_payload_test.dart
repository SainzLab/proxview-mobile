import 'package:flutter_test/flutter_test.dart';
import 'package:proxview/services/push_notification_service.dart';

void main() {
  group('AlertPushPayload', () {
    test('parses real alert payload from monitoringDaemon', () {
      final p = AlertPushPayload.fromData({
        'alert_id': '42',
        'target_name': 'PVE-Node-01',
        'severity': 'down',
        'action_type': 'Call',
        'message': 'Koneksi Timeout',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      });
      expect(p.alertId, 42);
      expect(p.isSimulation, isFalse);
      expect(p.isCall, isTrue);
      expect(p.severity, 'DOWN');
      expect(p.notificationId, 42);
      expect(p.callId, 'proxview-42');
      expect(p.toExtra()['alert_id'], '42');
    });

    test('handles simulation payload TEST-000 without FormatException', () {
      final p = AlertPushPayload.fromData({
        'alert_id': 'TEST-000',
        'target_name': 'SERVER UJI COBA (SIMULASI)',
        'severity': 'WARNING',
        'action_type': 'Pesan',
        'message': '[SIMULASI] Uji coba sistem untuk aksi: Pesan.',
      });
      expect(p.alertId, isNull);
      expect(p.isSimulation, isTrue);
      expect(p.isCall, isFalse);
      expect(p.notificationId, isNonNegative);
      expect(p.notificationId, lessThanOrEqualTo(0x7fffffff));
    });

    test('applies safe defaults for missing fields', () {
      final p = AlertPushPayload.fromData({'alert_id': '7'});
      expect(p.targetName, 'Monitoring Alert');
      expect(p.severity, 'WARNING');
      expect(p.actionType, 'Pesan');
      expect(p.isCall, isFalse);
    });

    test('ignores unrelated FCM payloads', () {
      expect(AlertPushPayload.isProxViewPayload({'foo': 'bar'}), isFalse);
      expect(AlertPushPayload.isProxViewPayload({'action_type': 'Call'}), isTrue);
    });
  });
}
