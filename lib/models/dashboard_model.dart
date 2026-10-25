class SystemStatusModel {
  final String proxmox;
  final String icmp;
  final String tcp;

  const SystemStatusModel({
    required this.proxmox,
    required this.icmp,
    required this.tcp,
  });

  factory SystemStatusModel.fromJson(Map<String, dynamic> json) {
    return SystemStatusModel(
      proxmox: json['proxmox']?.toString() ?? 'UNKNOWN',
      icmp: json['icmp']?.toString() ?? 'UNKNOWN',
      tcp: json['tcp']?.toString() ?? 'UNKNOWN',
    );
  }
}

class DashboardChartModel {
  final List<String> labels;
  final List<double> cpu;
  final List<double> ram;
  final List<double> io;

  const DashboardChartModel({
    required this.labels,
    required this.cpu,
    required this.ram,
    required this.io,
  });

  factory DashboardChartModel.fromJson(Map<String, dynamic> json) {
    return DashboardChartModel(
      labels: (json['labels'] as List?)?.map((e) => e.toString()).toList() ?? [],
      cpu: (json['cpu'] as List?)?.map((e) => (e as num?)?.toDouble() ?? 0.0).toList() ?? [],
      ram: (json['ram'] as List?)?.map((e) => (e as num?)?.toDouble() ?? 0.0).toList() ?? [],
      io: (json['io'] as List?)?.map((e) => (e as num?)?.toDouble() ?? 0.0).toList() ?? [],
    );
  }
}

class DashboardProxmoxSummary {
  final int totalNodes;
  final int onlineNodes;
  final int offlineNodes;
  final double healthPercent;
  final int totalVms;
  final int runningVms;
  final double avgCpu;
  final double avgRam;
  final double avgIo;
  final List<String> nodeNames;
  final DashboardChartModel chart;

  const DashboardProxmoxSummary({
    required this.totalNodes,
    required this.onlineNodes,
    required this.offlineNodes,
    required this.healthPercent,
    required this.totalVms,
    required this.runningVms,
    required this.avgCpu,
    required this.avgRam,
    required this.avgIo,
    required this.nodeNames,
    required this.chart,
  });

  factory DashboardProxmoxSummary.fromJson(Map<String, dynamic> json) {
    return DashboardProxmoxSummary(
      totalNodes: (json['total_nodes'] as num?)?.toInt() ?? 0,
      onlineNodes: (json['online_nodes'] as num?)?.toInt() ?? 0,
      offlineNodes: (json['offline_nodes'] as num?)?.toInt() ?? 0,
      healthPercent: (json['health_percent'] as num?)?.toDouble() ?? 0.0,
      totalVms: (json['total_vms'] as num?)?.toInt() ?? 0,
      runningVms: (json['running_vms'] as num?)?.toInt() ?? 0,
      avgCpu: (json['avg_cpu'] as num?)?.toDouble() ?? 0.0,
      avgRam: (json['avg_ram'] as num?)?.toDouble() ?? 0.0,
      avgIo: (json['avg_io'] as num?)?.toDouble() ?? 0.0,
      nodeNames: (json['node_names'] as List?)?.map((e) => e.toString()).toList() ?? [],
      chart: DashboardChartModel.fromJson(
        (json['chart'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

class DashboardProtocolSummary {
  final int total;
  final int active;
  final int up;
  final int down;
  final double avgLatencyMs;

  const DashboardProtocolSummary({
    required this.total,
    required this.active,
    required this.up,
    required this.down,
    required this.avgLatencyMs,
  });

  factory DashboardProtocolSummary.fromJson(Map<String, dynamic> json) {
    return DashboardProtocolSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
      avgLatencyMs: (json['avg_latency_ms'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RecentIncidentModel {
  final int id;
  final String ticketId;
  final String time;
  final String? resolvedAt;
  final String targetType;
  final String targetName;
  final String component;
  final String severity;
  final String originalSeverity;
  final String message;
  final bool isResolved;
  final String statusLabel;
  final String technicians;

  const RecentIncidentModel({
    required this.id,
    required this.ticketId,
    required this.time,
    this.resolvedAt,
    required this.targetType,
    required this.targetName,
    required this.component,
    required this.severity,
    required this.originalSeverity,
    required this.message,
    required this.isResolved,
    required this.statusLabel,
    required this.technicians,
  });

  factory RecentIncidentModel.fromJson(Map<String, dynamic> json) {
    return RecentIncidentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ticketId: json['ticket_id']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      resolvedAt: json['resolved_at']?.toString(),
      targetType: json['target_type']?.toString() ?? '',
      targetName: json['target_name']?.toString() ?? '',
      component: json['component']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'INFO',
      originalSeverity: json['original_severity']?.toString() ?? 'INFO',
      message: json['message']?.toString() ?? '',
      isResolved: json['is_resolved'] == true || json['is_resolved'] == 1,
      statusLabel: json['status_label']?.toString() ?? '',
      technicians: json['technicians']?.toString() ?? '-',
    );
  }
}

class DashboardSummaryModel {
  final int totalUsers;
  final int activeUsers;
  final int activeRoles;
  final DashboardProxmoxSummary proxmox;
  final DashboardProtocolSummary icmp;
  final DashboardProtocolSummary tcp;
  final List<RecentIncidentModel> recentIncidents;

  const DashboardSummaryModel({
    required this.totalUsers,
    required this.activeUsers,
    required this.activeRoles,
    required this.proxmox,
    required this.icmp,
    required this.tcp,
    required this.recentIncidents,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final usersJson = (json['users'] as Map<String, dynamic>?) ?? const {};
    return DashboardSummaryModel(
      totalUsers: (usersJson['total'] as num?)?.toInt() ?? 0,
      activeUsers: (usersJson['active'] as num?)?.toInt() ?? 0,
      activeRoles: (usersJson['active_roles'] as num?)?.toInt() ?? 0,
      proxmox: DashboardProxmoxSummary.fromJson(
        (json['proxmox'] as Map<String, dynamic>?) ?? const {},
      ),
      icmp: DashboardProtocolSummary.fromJson(
        (json['icmp'] as Map<String, dynamic>?) ?? const {},
      ),
      tcp: DashboardProtocolSummary.fromJson(
        (json['tcp'] as Map<String, dynamic>?) ?? const {},
      ),
      recentIncidents: (json['recent_incidents'] as List?)
              ?.map((e) => RecentIncidentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
