class ProxmoxTaskLogModel {
  final String upid;
  final String node;
  final String type;
  final String user;
  final String status;
  final dynamic startTime;
  final dynamic endTime;

  const ProxmoxTaskLogModel({
    required this.upid,
    required this.node,
    required this.type,
    required this.user,
    required this.status,
    this.startTime,
    this.endTime,
  });

  bool get isOk => status.toUpperCase() == 'OK' || status.toUpperCase() == 'RUNNING';

  factory ProxmoxTaskLogModel.fromJson(Map<String, dynamic> json) {
    return ProxmoxTaskLogModel(
      upid: json['upid']?.toString() ?? '',
      node: json['node']?.toString() ?? '',
      type: json['type']?.toString() ?? 'task',
      user: json['user']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'UNKNOWN',
      startTime: json['starttime'],
      endTime: json['endtime'],
    );
  }
}

class ProxmoxClusterLogModel {
  final dynamic time;
  final String node;
  final dynamic pri;
  final String tag;
  final String msg;
  final String user;

  const ProxmoxClusterLogModel({
    this.time,
    required this.node,
    this.pri,
    required this.tag,
    required this.msg,
    required this.user,
  });

  bool get isError =>
      msg.toLowerCase().contains('error') ||
      msg.toLowerCase().contains('fail') ||
      (pri is num && (pri as num) <= 3);

  factory ProxmoxClusterLogModel.fromJson(Map<String, dynamic> json) {
    return ProxmoxClusterLogModel(
      time: json['time'],
      node: json['node']?.toString() ?? '-',
      pri: json['pri'],
      tag: json['tag']?.toString() ?? 'system',
      msg: json['msg']?.toString() ?? '',
      user: json['user']?.toString() ?? '-',
    );
  }
}

class SystemAuditLogModel {
  final int id;
  final String level;
  final String source;
  final String message;
  final String timestamp;

  const SystemAuditLogModel({
    required this.id,
    required this.level,
    required this.source,
    required this.message,
    required this.timestamp,
  });

  factory SystemAuditLogModel.fromJson(Map<String, dynamic> json) {
    return SystemAuditLogModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      level: json['level']?.toString() ?? 'INFO',
      source: json['source']?.toString() ?? 'SYSTEM',
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}
