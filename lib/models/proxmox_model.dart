import '../core/utils/formatters.dart';

class ProxmoxServerModel {
  final int id;
  final String name;
  final String hostUrl;
  final String tokenId;
  final String status;
  final String latency;
  final String pveVersion;

  const ProxmoxServerModel({
    required this.id,
    required this.name,
    required this.hostUrl,
    required this.tokenId,
    required this.status,
    required this.latency,
    required this.pveVersion,
  });

  bool get isConnected =>
      status.toUpperCase() == 'TERHUBUNG' ||
      status.toUpperCase() == 'ONLINE' ||
      status.toUpperCase() == 'ACTIVE';

  factory ProxmoxServerModel.fromJson(Map<String, dynamic> json) {
    return ProxmoxServerModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      hostUrl: json['hostUrl']?.toString() ?? '',
      tokenId: json['tokenId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      latency: json['latency']?.toString() ?? '-',
      pveVersion: json['pveVersion']?.toString() ?? '-',
    );
  }
}

class ProxmoxNodeStatusModel {
  final String nodeName;
  final String status;
  final String cpuUsage;
  final int cpuCores;
  final String cpuModel;
  final String ramUsed;
  final String ramTotal;
  final String ramPercentage;
  final String ioDelay;
  final String loadAverage;
  final String uptime;
  final String rxIn;
  final String txOut;

  const ProxmoxNodeStatusModel({
    required this.nodeName,
    required this.status,
    required this.cpuUsage,
    required this.cpuCores,
    required this.cpuModel,
    required this.ramUsed,
    required this.ramTotal,
    required this.ramPercentage,
    required this.ioDelay,
    required this.loadAverage,
    required this.uptime,
    required this.rxIn,
    required this.txOut,
  });

  bool get isOnline => status.toLowerCase() == 'online';
  double get cpuPercentValue => Formatters.parsePercentage(cpuUsage);
  double get ramPercentValue => Formatters.parsePercentage(ramPercentage);
  double get ioDelayPercentValue => Formatters.parsePercentage(ioDelay);

  factory ProxmoxNodeStatusModel.fromJson(Map<String, dynamic> json) {
    final net = (json['network_traffic'] as Map<String, dynamic>?) ?? const {};
    return ProxmoxNodeStatusModel(
      nodeName: json['node_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'offline',
      cpuUsage: json['cpu_usage']?.toString() ?? '0 %',
      cpuCores: (json['cpu_cores'] as num?)?.toInt() ?? 0,
      cpuModel: json['cpu_model']?.toString() ?? '-',
      ramUsed: json['ram_used']?.toString() ?? '0 B',
      ramTotal: json['ram_total']?.toString() ?? '0 B',
      ramPercentage: json['ram_percentage']?.toString() ?? '0 %',
      ioDelay: json['io_delay']?.toString() ?? '0 %',
      loadAverage: json['load_average']?.toString() ?? '-',
      uptime: json['uptime']?.toString() ?? 'Offline',
      rxIn: net['rx_in']?.toString() ?? '0 B/s',
      txOut: net['tx_out']?.toString() ?? '0 B/s',
    );
  }
}

class ProxmoxGuestModel {
  final int vmid;
  final String name;
  final String node;
  final String type; // 'qemu' or 'lxc'
  final String status;
  final String cpuUsage;
  final int cpuCores;
  final String ramUsed;
  final String ramTotal;
  final String ramPercentage;
  final String diskUsed;
  final String diskTotal;
  final String uptime;
  final String netIn;
  final String netOut;

  const ProxmoxGuestModel({
    required this.vmid,
    required this.name,
    required this.node,
    required this.type,
    required this.status,
    required this.cpuUsage,
    required this.cpuCores,
    required this.ramUsed,
    required this.ramTotal,
    required this.ramPercentage,
    required this.diskUsed,
    required this.diskTotal,
    required this.uptime,
    required this.netIn,
    required this.netOut,
  });

  bool get isRunning => status.toLowerCase() == 'running';
  double get cpuPercentValue => Formatters.parsePercentage(cpuUsage);
  double get ramPercentValue => Formatters.parsePercentage(ramPercentage);

  factory ProxmoxGuestModel.fromJson(Map<String, dynamic> json, {required String guestType}) {
    return ProxmoxGuestModel(
      vmid: (json['vmid'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      node: json['node']?.toString() ?? '',
      type: guestType,
      status: json['status']?.toString() ?? 'stopped',
      cpuUsage: json['cpu_usage']?.toString() ?? '0 %',
      cpuCores: (json['cpu_cores'] as num?)?.toInt() ?? 0,
      ramUsed: json['ram_used']?.toString() ?? '0 B',
      ramTotal: json['ram_total']?.toString() ?? '0 B',
      ramPercentage: json['ram_percentage']?.toString() ?? '0 %',
      diskUsed: json['disk_used']?.toString() ?? '0 B',
      diskTotal: json['disk_total']?.toString() ?? '0 B',
      uptime: json['uptime']?.toString() ?? '-',
      netIn: json['net_in']?.toString() ?? '0 B',
      netOut: json['net_out']?.toString() ?? '0 B',
    );
  }
}

class ProxmoxStorageModel {
  final String storage;
  final String node;
  final String type;
  final String used;
  final String total;
  final String status;

  const ProxmoxStorageModel({
    required this.storage,
    required this.node,
    required this.type,
    required this.used,
    required this.total,
    this.status = '',
  });

  bool get isActive {
    if (status.isNotEmpty) {
      final s = status.toLowerCase();
      return s == 'available' || s == 'active' || s == 'online' || s == 'ok';
    }
    return total != '0 B' && total != '0' && total.isNotEmpty && total != '-';
  }

  factory ProxmoxStorageModel.fromJson(Map<String, dynamic> json) {
    return ProxmoxStorageModel(
      storage: json['storage']?.toString() ?? '',
      node: json['node']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      used: json['used']?.toString() ?? '0 B',
      total: json['total']?.toString() ?? '0 B',
      status: json['status']?.toString() ?? '',
    );
  }
}

class ProxmoxResourcesBundle {
  final List<ProxmoxGuestModel> vms;
  final List<ProxmoxGuestModel> lxcs;
  final List<ProxmoxStorageModel> storages;

  const ProxmoxResourcesBundle({
    required this.vms,
    required this.lxcs,
    required this.storages,
  });

  factory ProxmoxResourcesBundle.fromJson(Map<String, dynamic> json) {
    return ProxmoxResourcesBundle(
      vms: (json['vms'] as List?)
              ?.map((e) => ProxmoxGuestModel.fromJson(
                    e as Map<String, dynamic>,
                    guestType: 'qemu',
                  ))
              .toList() ??
          [],
      lxcs: (json['lxcs'] as List?)
              ?.map((e) => ProxmoxGuestModel.fromJson(
                    e as Map<String, dynamic>,
                    guestType: 'lxc',
                  ))
              .toList() ??
          [],
      storages: (json['storages'] as List?)
              ?.map((e) => ProxmoxStorageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
