class AlertModel {
  final int id;
  final int targetId;
  final String targetType;
  final String targetName;
  final String severity;
  final String originalSeverity;
  final String actionType; // "Pesan" | "Call"
  final String message;
  final bool isResolved;
  final String createdAt;
  final String? resolvedAt;
  final String? technicians;
  final int handlerCount;
  final String? handledAt;

  const AlertModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.targetName,
    required this.severity,
    required this.originalSeverity,
    required this.actionType,
    required this.message,
    required this.isResolved,
    required this.createdAt,
    this.resolvedAt,
    this.technicians,
    required this.handlerCount,
    this.handledAt,
  });

  bool get isEmergencyCall => actionType.toLowerCase() == 'call';
  bool get isBeingHandled => handlerCount > 0;
  bool get canResolve => severity.toUpperCase() == 'RECOVERED' && !isResolved;

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      targetId: (json['target_id'] as num?)?.toInt() ?? 0,
      targetType: json['target_type']?.toString() ?? '',
      targetName: json['target_name']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'WARNING',
      originalSeverity: json['original_severity']?.toString() ?? 'WARNING',
      actionType: json['action_type']?.toString() ?? 'Pesan',
      message: json['message']?.toString() ?? '',
      isResolved: json['is_resolved'] == 1 || json['is_resolved'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      resolvedAt: json['resolved_at']?.toString(),
      technicians: json['technicians']?.toString(),
      handlerCount: (json['handler_count'] as num?)?.toInt() ?? 0,
      handledAt: json['handled_at']?.toString(),
    );
  }
}

class IncidentTicketModel {
  final String ticketCode; // e.g. "#INC-2026-0076"
  final int dbId;
  final String time;
  final String? resolvedAt;
  final String title;
  final String target;
  final String status;
  final String severity;
  final String originalSeverity;
  final String? technicians;
  final bool isResolved;
  final String downtimeDuration;
  final String handlingDuration;

  const IncidentTicketModel({
    required this.ticketCode,
    required this.dbId,
    required this.time,
    this.resolvedAt,
    required this.title,
    required this.target,
    required this.status,
    required this.severity,
    required this.originalSeverity,
    this.technicians,
    required this.isResolved,
    required this.downtimeDuration,
    required this.handlingDuration,
  });

  bool get canResolve => severity.toUpperCase() == 'RECOVERED' && !isResolved;
  bool get isUnhandled =>
      !isResolved &&
      (technicians == null || technicians!.trim().isEmpty || technicians == '-');

  factory IncidentTicketModel.fromJson(Map<String, dynamic> json) {
    return IncidentTicketModel(
      ticketCode: json['id']?.toString() ?? '',
      dbId: (json['db_id'] as num?)?.toInt() ?? 0,
      time: json['time']?.toString() ?? '',
      resolvedAt: json['resolved_at']?.toString(),
      title: json['title']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'WARNING',
      originalSeverity: json['original_severity']?.toString() ?? 'WARNING',
      technicians: json['technicians']?.toString(),
      isResolved: json['is_resolved'] == 1 || json['is_resolved'] == true,
      downtimeDuration: json['downtime_duration']?.toString() ?? '-',
      handlingDuration: json['handling_duration']?.toString() ?? '-',
    );
  }
}
