import 'package:flutter_test/flutter_test.dart';
import 'package:proxview/models/analytics_model.dart';
import 'package:proxview/models/network_tool_model.dart';

void main() {
  group('Analitik SLA & MTBF V2 Models', () {
    test('SlaSummaryModel parses MTBF & formatted durations from V2 payload', () {
      final summary = SlaSummaryModel.fromJson({
        'period': '24h',
        'severity': 'ALL',
        'total_period_sec': 86400,
        'total_uptime_sec': 85200,
        'uptime_duration': '23j 40m',
        'total_downtime_sec': 1200,
        'downtime_duration': '20m',
        'incident_count': 2,
        'mttr_sec': 600,
        'mttr_duration': '10m',
        'mtbf_sec': 42600,
        'mtbf_duration': '11j 50m',
        'availability': '98.61',
        'availability_num': 98.61,
        'availability_percent': '98.61%',
      });

      expect(summary.totalUptimeSec, 85200);
      expect(summary.uptimeDuration, '23j 40m');
      expect(summary.mttrSec, 600);
      expect(summary.mttrDuration, '10m');
      expect(summary.mtbfSec, 42600);
      expect(summary.mtbfDuration, '11j 50m');
      expect(summary.availability, closeTo(98.61, 0.001));
      expect(summary.availabilityPercent, '98.61%');
    });

    test('SlaSummaryModel handles 0 incidents (MTBF == Uptime) & legacy fallback', () {
      final summary = SlaSummaryModel.fromJson({
        'period': '24h',
        'severity': 'ALL',
        'total_period_sec': 86400,
        'total_uptime_sec': 86400,
        'total_downtime_sec': 0,
        'incident_count': 0,
        'mttr_sec': 0,
        'availability': '100.00',
      });

      expect(summary.mtbfSec, 86400);
      expect(summary.mtbfDuration.isNotEmpty, isTrue);
      expect(summary.availability, 100.0);
    });

    test('SlaAnalyticsResponseModel parses chartData with MTBF fields', () {
      final res = SlaAnalyticsResponseModel.fromJson({
        'success': true,
        'summary': {
          'period': '24h',
          'severity': 'WARNING',
          'total_period_sec': 86400,
          'total_uptime_sec': 86400,
          'uptime_duration': '1 hari',
          'total_downtime_sec': 0,
          'downtime_duration': '0d',
          'total_degradation_sec': 300,
          'degradation_duration': '5m',
          'incident_count': 1,
          'mttr_sec': 0,
          'mttr_duration': '0d',
          'mtbf_sec': 86400,
          'mtbf_duration': '1 hari',
          'availability': '100.00',
        },
        'chartData': [
          {
            'label': '10:00',
            'total_period_sec': 3600,
            'total_uptime_sec': 2700,
            'uptime_duration': '45m',
            'total_downtime_sec': 900,
            'downtime_duration': '15m',
            'incident_count': 1,
            'mttr_sec': 900,
            'mttr_duration': '15m',
            'mtbf_sec': 2700,
            'mtbf_duration': '45m',
            'availability': '75.00',
          },
        ],
      });

      expect(res.summary.totalDegradationSec, 300);
      expect(res.summary.degradationDuration, '5m');
      expect(res.chartData.length, 1);
      expect(res.chartData.first.mtbfSec, 2700);
      expect(res.chartData.first.mtbfDuration, '45m');
    });
  });

  group('Network Tools Validation & Models', () {
    test('validates Ping & Traceroute targets and blocks OS command injection', () {
      expect(NetworkToolValidator.validateHostOrDomain('8.8.8.8'), isNull);
      expect(NetworkToolValidator.validateHostOrDomain('google.com'), isNull);
      expect(
        NetworkToolValidator.validateHostOrDomain('2001:4860:4860::8888'),
        isNull,
      );
      expect(
        NetworkToolValidator.validateHostOrDomain('8.8.8.8; rm -rf /'),
        isNotNull,
      );
      expect(
        NetworkToolValidator.validateHostOrDomain('8.8.8.8 && whoami'),
        isNotNull,
      );
      expect(NetworkToolValidator.validateHostOrDomain(''), isNotNull);
    });

    test('validates IP Scan CIDR ranges for IPv4 (/16../32) and IPv6 (/1../128)', () {
      expect(
        NetworkToolValidator.validateIpScanTarget('192.168.1.0/24'),
        isNull,
      );
      expect(
        NetworkToolValidator.validateIpScanTarget('192.168.1.10'),
        isNull,
      );
      expect(
        NetworkToolValidator.validateIpScanTarget('2001:db8::/64'),
        isNull,
      );
      // Prefix /8 pada IPv4 harus ditolak (di luar batas aman /16 s.d. /32)
      expect(
        NetworkToolValidator.validateIpScanTarget('10.0.0.0/8'),
        isNotNull,
      );
      // Oktet > 255 harus ditolak
      expect(
        NetworkToolValidator.validateIpScanTarget('192.168.999.0/24'),
        isNotNull,
      );
    });

    test('generates accurate IPv4 vs IPv6 OS command previews', () {
      expect(
        NetworkToolType.ping.commandPreview('8.8.8.8'),
        equals('ping -c 10 8.8.8.8'),
      );
      expect(
        NetworkToolType.ping.commandPreview('2001:4860::8888'),
        equals('ping -6 -c 4 2001:4860::8888'),
      );
      expect(
        NetworkToolType.ipScan.commandPreview('2001:db8::/64'),
        equals('nmap -6 -sn 2001:db8::/64'),
      );
    });
  });
}
