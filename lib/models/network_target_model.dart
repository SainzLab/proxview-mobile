class NetworkTargetModel {
  final int id;
  final String name;
  final String description;
  final String protocol; // "ICMP PING" | "TCP SOCKET"
  final String ipAddress;
  final int? port;
  final int checkInterval;
  final int maxRetries;
  final String status; // "UP" | "DOWN"
  final String lastLatency;
  final bool isActive;
  final bool isAlertEnabled;
  final int latencyWarning;
  final int latencyCritical;
  final String? lastCheck;

  const NetworkTargetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.protocol,
    required this.ipAddress,
    this.port,
    required this.checkInterval,
    required this.maxRetries,
    required this.status,
    required this.lastLatency,
    required this.isActive,
    required this.isAlertEnabled,
    required this.latencyWarning,
    required this.latencyCritical,
    this.lastCheck,
  });

  bool get isUp => status.toUpperCase() == 'UP';

  factory NetworkTargetModel.fromJson(Map<String, dynamic> json) {
    return NetworkTargetModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      protocol: json['protocol']?.toString() ?? 'ICMP PING',
      ipAddress: json['ip_address']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt(),
      checkInterval: (json['check_interval'] as num?)?.toInt() ?? 10,
      maxRetries: (json['max_retries'] as num?)?.toInt() ?? 3,
      status: json['status']?.toString() ?? 'DOWN',
      lastLatency: json['last_latency']?.toString() ?? '0 ms',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isAlertEnabled: json['is_alert_enabled'] == 1 || json['is_alert_enabled'] == true,
      latencyWarning: (json['latency_warning'] as num?)?.toInt() ?? 50,
      latencyCritical: (json['latency_critical'] as num?)?.toInt() ?? 150,
      lastCheck: json['last_check']?.toString(),
    );
  }
}

class TargetLatencyPointModel {
  final double latencyMs;
  final String status;
  final String time;

  const TargetLatencyPointModel({
    required this.latencyMs,
    required this.status,
    required this.time,
  });

  factory TargetLatencyPointModel.fromJson(Map<String, dynamic> json) {
    return TargetLatencyPointModel(
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'UP',
      time: json['time']?.toString() ?? '',
    );
  }
}
